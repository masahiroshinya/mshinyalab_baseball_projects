// Affinity への接続と、作業フォルダ（デスクトップの affinity_mcp_work）の読み込みを確かめる（読み取りだけ。2026-10-20）
// Affinity が起動していない、または MCP が有効でないときは、このスクリプトに届く前に、クライアント（tools/affinity-mcp.mjs）が接続の失敗を出す。
//
// 結果の行：
//   [OK] connection   接続できたことと、開いている文書の数
//   [OK] / [NG] desktop  作業フォルダの読み込み（NG のときは、設定 > モデルコンテキストプロトコル の「デスクトップ上のファイルへのアクセス」を確かめる）
// 実行（figure-toolkit のフォルダで）：node tools/affinity-mcp.mjs run affinity/compose/check_connection.js
// 作業フォルダがまだないときは、desktop が NG になる（作業フォルダを作ってから、もう一度確かめる）。

const { app } = require('/application') ;
const { DirectoryIterator } = require('/fs') ;

const pathSeparator = app.userDesktopPath.includes('\\') ? '\\' : '/' ;
const workDir = [app.userDesktopPath, 'affinity_mcp_work'].join(pathSeparator) ;

console.log(`[OK] connection: 開いている文書 ${app.documents.all.length} 個`) ;
try {
    const iterator = DirectoryIterator.at(workDir) ;
    let count = 0 ;
    while (!iterator.isDone()) {
        count += 1 ;
        iterator.next() ;
    }
    console.log(`[OK] desktop: ${workDir} を読めた（${count} 項目）`) ;
} catch (error) {
    console.log(`[NG] desktop: ${workDir} を読めない（${error.message}）。設定 > モデルコンテキストプロトコル の「デスクトップ上のファイルへのアクセス」を確かめる。作業フォルダがない場合は作ってから確かめる`) ;
}
