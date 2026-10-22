#!/usr/bin/env node
// Affinity 内蔵 MCP サーバー（http://[::1]:6767/sse）に接続する最小クライアント。
// 外部パッケージを使わず、Node.js 18 以降の標準モジュールだけで動く。
//
// 前提：
//   Affinity 3.2 以降を起動し、設定 > Model Context Protocol で MCP サーバーとスクリプトを有効にしておく。
//   サーバーは IPv6 ループバック（::1）だけで待ち受けるため、127.0.0.1 では接続できない。
//
// 使い方（figure-toolkit/ で実行。書き出したファイルを移す先は AFFINITY_COLLECT_DIR に絶対パスで指定する）：
//   node tools/affinity-mcp.mjs tools                     公開されているツール一覧
//   node tools/affinity-mcp.mjs docs-list                 SDK ドキュメントの項目一覧
//   node tools/affinity-mcp.mjs doc <filename>            SDK ドキュメントを1項目表示
//   node tools/affinity-mcp.mjs docs-dump <outDir>        SDK ドキュメントを全項目保存
//   node tools/affinity-mcp.mjs run <script.js> [--set 名前=値 ...]
//                                                         スクリプトを実行し console.log の出力を表示
//                                                         （デスクトップの affinity_mcp_work/export/ に書き出されたファイルは AFFINITY_COLLECT_DIR へ移す。
//                                                          指定がなければ移さずに export/ に残す）
//                                                         --set は、スクリプトの先頭に globalThis.名前 = 値 を加える（値は JSON。読めなければ文字列）
//   node tools/affinity-mcp.mjs render <index> <out.jpg> [uuid]  見開きを JPEG で保存（uuid 省略時は現在のドキュメント）
//   node tools/affinity-mcp.mjs hints <query>             SDK ヒントを検索
//   node tools/affinity-mcp.mjs library                   スクリプトパネルに登録済みのスクリプト一覧
//   node tools/affinity-mcp.mjs save <題名> <説明> <script.js>  スクリプトパネルへ登録（同じ題名があると登録できない。パネルで削除してから登録し直す）
//   node tools/affinity-mcp.mjs call <tool> '<json>'      任意のツールを引数付きで呼ぶ

import http from 'node:http' ;
import fs from 'node:fs' ;
import os from 'node:os' ;
import path from 'node:path' ;

// 接続先と MCP のプロトコル版（Affinity 3.3 はこの版だけを受け付けるとの報告がある）
const serverHost = process.env.AFFINITY_MCP_HOST || '::1' ;
const serverPort = Number(process.env.AFFINITY_MCP_PORT || 6767) ;
const protocolVersion = process.env.AFFINITY_MCP_PROTOCOL || '2025-11-25' ;
const requestTimeoutMs = 120000 ; // 1 回の JSON-RPC 応答を待つ上限 [ms]

// MCP 経由のスクリプトはデスクトップ配下しか読み書きできないため、デスクトップに作業フォルダを置く。
// スクリプトが export/ に書き出したファイルは、run の後に collectDir（AFFINITY_COLLECT_DIR）へ移す。
// 指定がなければ移さない（toolkit のフォルダや実行した場所に、成果物を置かないため。2026-10-20）
const workDir = process.env.AFFINITY_WORK_DIR || path.join(os.homedir(), 'Desktop', 'affinity_mcp_work') ;
const exportDir = path.join(workDir, 'export') ;
const collectDir = process.env.AFFINITY_COLLECT_DIR || '' ;


// ---------------------------------------------------------------
// SSE セッション：GET /sse で受信路を開き、endpoint イベントで通知された URL へ POST する
// ---------------------------------------------------------------
class AffinitySession {
    constructor() {
        this.postPath = null ;       // サーバーが通知するセッション固有の POST 先
        this.pending = new Map() ;   // 応答待ちの JSON-RPC id → { resolve, reject, timer }
        this.nextId = 1 ;
        this.sseRequest = null ;
    }

    // SSE 接続を開き、POST 先が通知されるまで待つ
    open() {
        return new Promise((resolve, reject) => {
            const requestOptions = {
                host: serverHost,
                port: serverPort,
                path: '/sse',
                method: 'GET',
                headers: { Accept: 'text/event-stream' },
            } ;
            this.sseRequest = http.request(requestOptions, (response) => {
                if (response.statusCode !== 200) {
                    reject(new Error(`SSE 接続に失敗しました（HTTP ${response.statusCode}）`)) ;
                    return ;
                }
                response.setEncoding('utf8') ;

                // SSE はイベントを空行で区切る。行をまたいで届く断片をバッファで連結する
                let buffer = '' ;
                response.on('data', (chunk) => {
                    buffer += chunk.replace(/\r\n/g, '\n') ;
                    let separatorIndex = buffer.indexOf('\n\n') ;
                    while (separatorIndex >= 0) {
                        const rawEvent = buffer.slice(0, separatorIndex) ;
                        buffer = buffer.slice(separatorIndex + 2) ;
                        this.handleEvent(rawEvent, resolve) ;
                        separatorIndex = buffer.indexOf('\n\n') ;
                    }
                }) ;
                response.on('end', () => {
                    this.rejectAll(new Error('SSE 接続がサーバー側で閉じられました')) ;
                }) ;
            }) ;
            this.sseRequest.on('error', (error) => {
                const hint = 'Affinity が起動しているか、設定で MCP サーバーが有効かを確認してください' ;
                reject(new Error(`${error.message}\n${hint}`)) ;
            }) ;
            this.sseRequest.end() ;
        }) ;
    }

    // 1 件の SSE イベント（event: と data: の行）を解釈する
    handleEvent(rawEvent, resolveOpen) {
        let eventName = 'message' ;
        const dataLines = [] ;
        for (const line of rawEvent.split('\n')) {
            if (line.startsWith('event:')) {
                eventName = line.slice(6).trim() ;
            } else if (line.startsWith('data:')) {
                dataLines.push(line.slice(5).trimStart()) ;
            }
        }
        const data = dataLines.join('\n') ;

        // 最初に届く endpoint イベントが POST 先（相対パス）を示す
        if (eventName === 'endpoint') {
            const endpointUrl = new URL(data, `http://[${serverHost}]:${serverPort}`) ;
            this.postPath = endpointUrl.pathname + endpointUrl.search ;
            resolveOpen() ;
            return ;
        }
        if (eventName !== 'message' || data === '') {
            return ;
        }

        // JSON-RPC 応答を id で対応する要求へ返す
        const message = JSON.parse(data) ;
        const waiter = this.pending.get(message.id) ;
        if (waiter === undefined) {
            return ;
        }
        clearTimeout(waiter.timer) ;
        this.pending.delete(message.id) ;
        if (message.error) {
            waiter.reject(new Error(`JSON-RPC エラー ${message.error.code}: ${message.error.message}` +
                (message.error.data ? `\n${JSON.stringify(message.error.data)}` : ''))) ;
        } else {
            waiter.resolve(message.result) ;
        }
    }

    // POST 先へ JSON-RPC メッセージを送る（応答本体は SSE 側で受け取る）
    post(message) {
        return new Promise((resolve, reject) => {
            const body = JSON.stringify(message) ;
            const requestOptions = {
                host: serverHost,
                port: serverPort,
                path: this.postPath,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(body),
                },
            } ;
            const postRequest = http.request(requestOptions, (response) => {
                response.resume() ;
                if (response.statusCode >= 400) {
                    reject(new Error(`POST に失敗しました（HTTP ${response.statusCode}）。セッションが切れた可能性があります`)) ;
                } else {
                    resolve() ;
                }
            }) ;
            postRequest.on('error', reject) ;
            postRequest.end(body) ;
        }) ;
    }

    // 応答を伴う JSON-RPC 要求
    request(method, params) {
        const id = this.nextId ;
        this.nextId += 1 ;
        const responsePromise = new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
                this.pending.delete(id) ;
                reject(new Error(`${method} の応答が ${requestTimeoutMs / 1000} 秒以内に届きませんでした`)) ;
            }, requestTimeoutMs) ;
            this.pending.set(id, { resolve, reject, timer }) ;
        }) ;
        const sendPromise = this.post({ jsonrpc: '2.0', id, method, params }) ;
        return sendPromise.then(() => responsePromise) ;
    }

    // 応答を伴わない JSON-RPC 通知
    notify(method, params) {
        return this.post({ jsonrpc: '2.0', method, params }) ;
    }

    rejectAll(error) {
        for (const waiter of this.pending.values()) {
            clearTimeout(waiter.timer) ;
            waiter.reject(error) ;
        }
        this.pending.clear() ;
    }

    close() {
        if (this.sseRequest) {
            this.sseRequest.destroy() ;
        }
    }

    // MCP の初期化手順：initialize 要求 → initialized 通知
    async initialize() {
        const initParams = {
            protocolVersion,
            capabilities: {},
            clientInfo: { name: 'figure-toolkit-affinity-mcp', version: '0.1.0' },
        } ;
        const serverInfo = await this.request('initialize', initParams) ;
        await this.notify('notifications/initialized', {}) ;
        return serverInfo ;
    }

    // ツール呼び出し。結果は MCP の content 配列（text / image）で返る
    async callTool(toolName, toolArguments) {
        const result = await this.request('tools/call', { name: toolName, arguments: toolArguments }) ;
        if (result.isError) {
            const errorText = contentText(result) ;
            throw new Error(`ツール ${toolName} がエラーを返しました：\n${errorText}`) ;
        }
        return result ;
    }

    // execute_script とほとんどの SDK ドキュメントは、同じ接続で preamble を読んだ後でないと使えない
    async readPreamble() {
        return this.callTool('read_sdk_documentation_topic', { filename: 'preamble' }) ;
    }
}


// MCP の content 配列から text 要素だけを連結する
function contentText(result) {
    const textParts = (result.content || [])
        .filter((item) => item.type === 'text')
        .map((item) => item.text) ;
    return textParts.join('\n') ;
}

// MCP の content 配列から最初の image 要素を取り出す
function contentImage(result) {
    return (result.content || []).find((item) => item.type === 'image') ;
}


// ---------------------------------------------------------------
// サブコマンド
// ---------------------------------------------------------------
async function main() {
    const [command, ...args] = process.argv.slice(2) ;
    if (!command) {
        console.error('使い方はファイル冒頭のコメントを参照してください') ;
        process.exit(1) ;
    }

    const session = new AffinitySession() ;
    await session.open() ;
    const serverInfo = await session.initialize() ;
    console.error(`[接続] ${serverInfo.serverInfo?.name ?? 'Affinity'} ${serverInfo.serverInfo?.version ?? ''}` +
        `（protocol ${serverInfo.protocolVersion}）`) ;

    try {
        if (command === 'tools') {
            const toolList = await session.request('tools/list', {}) ;
            for (const tool of toolList.tools) {
                const argumentNames = Object.keys(tool.inputSchema?.properties ?? {}) ;
                console.log(`## ${tool.name}(${argumentNames.join(', ')})\n${tool.description ?? ''}\n`) ;
            }
        } else if (command === 'docs-list') {
            const result = await session.callTool('list_sdk_documentation', {}) ;
            console.log(contentText(result)) ;
        } else if (command === 'doc') {
            const topicName = args[0] ;
            if (topicName !== 'preamble') {
                await session.readPreamble() ;
            }
            const result = await session.callTool('read_sdk_documentation_topic', { filename: topicName }) ;
            console.log(contentText(result)) ;
        } else if (command === 'docs-dump') {
            await dumpDocs(session, args[0] || 'sdk-docs') ;
        } else if (command === 'run') {
            await runScript(session, args[0], parseSetOptions(args.slice(1))) ;
        } else if (command === 'render') {
            if (!args[1]) {
                throw new Error('render には保存先（<out.jpg>）を指定する') ;
            }
            await renderSpread(session, Number(args[0] || 0), args[1], args[2]) ;
        } else if (command === 'hints') {
            const result = await session.callTool('search_sdk_hints', { prompt: args.join(' ') }) ;
            console.log(contentText(result)) ;
        } else if (command === 'library') {
            const result = await session.callTool('list_library_scripts', {}) ;
            console.log(contentText(result)) ;
        } else if (command === 'save') {
            // スクリプトパネルへ登録する（同じ題名があると登録できない：2026-10-19 確認）。引数：題名、説明、スクリプトのファイル
            const code = fs.readFileSync(args[2], 'utf8') ;
            await session.readPreamble() ;
            const result = await session.callTool('save_script_to_library', { title: args[0], description: args[1], code }) ;
            console.log(contentText(result)) ;
        } else if (command === 'call') {
            const toolArguments = args[1] ? JSON.parse(args[1]) : {} ;
            await session.readPreamble() ;
            const result = await session.callTool(args[0], toolArguments) ;
            console.log(contentText(result)) ;
        } else {
            throw new Error(`未知のコマンド：${command}`) ;
        }
    } finally {
        session.close() ;
    }
}

// SDK ドキュメント全項目をファイルに保存する（既存ファイルは飛ばすので、途中で切れても再実行で続きを取れる）
async function dumpDocs(session, outDir) {
    fs.mkdirSync(outDir, { recursive: true }) ;
    const listResult = await session.callTool('list_sdk_documentation', {}) ;
    const listText = contentText(listResult) ;
    fs.writeFileSync(path.join(outDir, '_index.csv'), listText) ;

    // 一覧はファイル名をカンマで区切った 1 行で返る（3.3.1 で確認）。改行区切りにも対応しておく
    const topicNames = listText.split(/[,\r\n]+/)
        .map((name) => name.trim().replace(/^"|"$/g, ''))
        .filter((name) => name !== '') ;

    // preamble を最初に読む
    const preambleResult = await session.readPreamble() ;
    fs.writeFileSync(path.join(outDir, 'preamble.md'), contentText(preambleResult)) ;

    for (const topicName of topicNames) {
        // examples/・tests/ などのサブフォルダはそのまま再現する
        const outFile = path.join(outDir, ...topicName.split('/')) ;
        if (topicName === 'preamble' || fs.existsSync(outFile)) {
            continue ;
        }
        const result = await session.callTool('read_sdk_documentation_topic', { filename: topicName }) ;
        fs.mkdirSync(path.dirname(outFile), { recursive: true }) ;
        fs.writeFileSync(outFile, contentText(result)) ;
        console.error(`[保存] ${outFile}`) ;
    }
}

// run の --set 名前=値 を、スクリプトの前に置く globalThis の代入にする（値は JSON として読み、読めなければ文字列とする）。
// 例：--set testFigureName=draft_figures_2x2 --set 'panelNames=["jump_height"]'
// スクリプトに値を渡すために、前置きのファイルを連結しなくてよいようにする（2026-10-19）
function parseSetOptions(options) {
    const assignments = [] ;
    for (let index = 0 ; index < options.length ; index++) {
        if (options[index] !== '--set') {
            throw new Error(`run の引数が読めません：${options[index]}（--set 名前=値 の形で指定する）`) ;
        }
        const assignment = options[index + 1] ?? '' ;
        const separator = assignment.indexOf('=') ;
        const name = assignment.slice(0, separator) ;
        if (separator <= 0 || !/^[A-Za-z_$][\w$]*$/.test(name)) {
            throw new Error(`--set の指定が読めません：${assignment}`) ;
        }
        const text = assignment.slice(separator + 1) ;
        let value ;
        try {
            value = JSON.parse(text) ;
        } catch {
            value = text ;
        }
        assignments.push(`globalThis.${name} = ${JSON.stringify(value)} ;`) ;
        index += 1 ;
    }
    return assignments ;
}

// スクリプトファイルを実行し、console.log の出力を表示する（戻り値は返らない仕様）。assignments はスクリプトの前に置く行
async function runScript(session, scriptPath, assignments = []) {
    const scriptSource = [...assignments, fs.readFileSync(scriptPath, 'utf8')].join('\n') ;
    await session.readPreamble() ;
    const result = await session.callTool('execute_script', { script: scriptSource }) ;
    const outputText = contentText(result) ;
    console.log(outputText) ;

    // スクリプト内の例外も isError ではなく通常の出力として返るため、出力から判定して終了コードに反映する
    if (/^\w*Error\b.*:/m.test(outputText) || /^\s+at .*main:\d+/m.test(outputText)) {
        process.exitCode = 1 ;
    }

    collectExports() ;
}

// 作業フォルダの export/ にあるファイルを collectDir へ移す（同名ファイルは上書き）。collectDir の指定がなければ移さずに知らせる
function collectExports() {
    if (!fs.existsSync(exportDir)) {
        return ;
    }
    const exportedNames = fs.readdirSync(exportDir)
        .filter((name) => fs.statSync(path.join(exportDir, name)).isFile()) ;
    if (exportedNames.length === 0) {
        return ;
    }
    if (collectDir === '') {
        console.error(`[移動しない] AFFINITY_COLLECT_DIR が指定されていないので、書き出したファイル（${exportedNames.length} 個）は ${exportDir} に残した`) ;
        return ;
    }
    fs.mkdirSync(collectDir, { recursive: true }) ;
    for (const name of exportedNames) {
        const sourcePath = path.join(exportDir, name) ;
        const destinationPath = path.join(collectDir, name) ;
        // ドライブをまたぐ移動では rename が使えないため、複製してから元を消す
        fs.copyFileSync(sourcePath, destinationPath) ;
        fs.unlinkSync(sourcePath) ;
        console.error(`[移動] ${destinationPath}`) ;
    }
}

// ドキュメントの見開きを JPEG（長辺 1024 px 以下）で保存する。UUID を省略すると現在のドキュメント
async function renderSpread(session, spreadIndex, outFile, givenUuid) {
    await session.readPreamble() ;

    // render_spread はドキュメントのセッション UUID を要求するので、指定がなければスクリプトで取得する
    let documentSessionUuid = givenUuid ;
    if (!documentSessionUuid) {
        const uuidScript = "const { app } = require('/application') ;\nconsole.log(app.documents.current.sessionUuid) ;" ;
        const uuidResult = await session.callTool('execute_script', { script: uuidScript }) ;
        documentSessionUuid = contentText(uuidResult).trim().split(/\s+/).pop() ;
    }

    const renderArguments = { document_session_uuid: documentSessionUuid, spread_index: spreadIndex } ;
    const renderResult = await session.callTool('render_spread', renderArguments) ;
    const image = contentImage(renderResult) ;
    if (image === undefined) {
        throw new Error(`画像が返りませんでした：\n${contentText(renderResult)}`) ;
    }
    fs.mkdirSync(path.dirname(outFile), { recursive: true }) ;
    fs.writeFileSync(outFile, Buffer.from(image.data, 'base64')) ;
    console.log(`[保存] ${outFile}（${image.mimeType}）`) ;
}


main().catch((error) => {
    console.error(error.message) ;
    process.exit(1) ;
}) ;
