// 仕上げた図の書き出し（ユーザーが Affinity で仕上げた図を、投稿用の PDF・PNG・TIFF に書き出す。2026-10-20）
//
// 対象の図は変更しない（保存も閉じることもしない）。手順：
//   1. 対象の図の最初のページを PDF に書き出す（PDF を頼まれていれば、それが成果物になる）。
//   2. PNG・TIFF・CMYK を頼まれていれば、対象の図を PDF に書き出して AI の文書として開き直し、その文書の dpi（と色形式）を変えてから
//      書き出す。ラスターの dpi は、文書の dpi を変えないと正しく記録されない（開発時の試行 G7）。対象の図の dpi を変えない
//      ために、開き直した文書で行う。開き直した文書は書き出した後に閉じる（保存しない）。
//   3. 書き出したファイルを開き直し、ページの大きさと dpi を確かめる。
// 引数（--set）：
//   exportTitle   対象の図の文書の名前（必須。Affinity のタブの名前）
//   formats       書き出す形式（カンマ区切り。pdf、png、tiff。既定 pdf,png）
//   dpi           PNG・TIFF の解像度（既定 600）
//   pdfx          true なら PDF を PDF/X-4 にする（印刷用の規格を求められたとき。既定 false）
//   cmyk          true なら CMYK で書き出す（PDF はプレス品質、TIFF は CMYK。PNG は RGB のまま。既定 false）
// 報告：[file] の行に、対象の図の .af の保存場所（未保存の新規の図なら空）と、デスクトップの作業フォルダの中かどうかを出す
//       （AI が、.af を書き出し先と同じフォルダに保存するかを提案するため。AGENTS.md の 4 節の 11）。
// 出力：affinity_mcp_work/export/<exportTitle>_final.pdf、<exportTitle>_final_<dpi>dpi.png・.tif（CMYK は名前に _cmyk）。
//       クライアントが AFFINITY_COLLECT_DIR へ移す。途中で作る affinity_mcp_work/export_source_<exportTitle>.pdf は、確認の後に削除する。
// 実行（figure-toolkit のフォルダで）：
//   AFFINITY_COLLECT_DIR=<保存先>/<図の名前>/output node tools/affinity-mcp.mjs run affinity/compose/export_figure.js --set exportTitle=<題名> --set formats=pdf,png
// 既定値の理由（docs/figure-assembly-style.md の 3 節）：PDF はベクターのまま、フォントを埋め込む「書き出し用」のプリセット。
//   PNG・TIFF の 600 dpi は、線と文字を含む図で投稿規程によく求められる値（規程に指定があれば、それに従う）。

const { app } = require('/application') ;
const { Document, FileExportOptions, FileExportArea, RasterFormat } = require('/document') ;
const { DocumentProperties } = require('/documentproperties') ;
const { fs } = require('/fs') ;

const pathSeparator = app.userDesktopPath.includes('\\') ? '\\' : '/' ;
const joinPath = (...parts) => parts.join(pathSeparator) ;
const workDir = joinPath(app.userDesktopPath, 'affinity_mcp_work') ;
const exportDir = joinPath(workDir, 'export') ;

// 書き出しのプリセット：名前は Affinity の表示の言語で変わるので、日本語と英語の名前、なければ名前の形で探す
const presetCandidates = {
    pdf: { names: ['PDF(書き出し用)', 'PDF (for export)'], pattern: /^PDF.*(書き出し|export)/i },
    pdfPress: { names: ['PDF(プレス品質)', 'PDF (press ready)'], pattern: /^PDF.*(プレス|press)/i },
    pdfx4: { names: ['PDF/X-4'], pattern: /^PDF\/X-4/ },
    png: { names: ['PNG'], pattern: /^PNG$/ },
    tiff: { names: ['TIFF RGB 8ビット', 'TIFF RGB 8-bit'], pattern: /^TIFF RGB 8/ },
    tiffCmyk: { names: ['TIFF CMYK'], pattern: /^TIFF CMYK/ },
} ;
function presetName(kind) {
    const available = FileExportOptions.allPresetNames ;
    const candidate = presetCandidates[kind] ;
    const name = candidate.names.find((item) => available.includes(item)) ?? available.find((item) => candidate.pattern.test(item)) ;
    if (!name) {
        throw new Error(`書き出しのプリセット（${kind}）が見つからない。使えるプリセット：${available.join(', ')}`) ;
    }
    return name ;
}

// 最初のページを書き出す（複数ページの文書でページ範囲を指定したラスターは名前に _1 が付くので付け直す。1 ページの文書では付かない）
function exportFile(doc, path, kind) {
    const records = doc.export(path, FileExportOptions.createWithPresetName(presetName(kind)), FileExportArea.createForPages('1')) ;
    for (const record of records.all) {
        if (!record.isSuccess) {
            throw new Error(`${path} の書き出しに失敗（${record.errorMessage}）`) ;
        }
    }
    try {
        fs.rename(path.replace(/(\.[a-z]+)$/, '_1$1'), path) ;
    } catch (error) {
        if (!/NO_SUCH_FILE/.test(error.message)) {
            console.log(`[export] rename: ${error.message}`) ;
        }
    }
}

// 書き出したファイルを開き直して、ページの大きさと dpi を確かめる
function verify(path, label) {
    const exported = Document.load(path) ;
    const box = exported.spreads.toArray()[0].getSpreadBaseBox() ;
    const pxPerMm = exported.dpi/25.4 ;
    console.log(`[OK] ${label}: ${path}（${(box.width/pxPerMm).toFixed(1)} x ${(box.height/pxPerMm).toFixed(1)} mm、${exported.dpi} dpi）`) ;
    exported.close() ;
}

function exportFigure(doc, title, formats, dpi, usePdfx, useCmyk) {
    const baseName = `${title}_final` ;
    const written = [] ; // 確かめるファイル [場所, 名前]

    // 1. 対象の図の PDF（RGB）
    if (formats.includes('pdf') && !useCmyk) {
        const pdfPath = joinPath(exportDir, `${baseName}.pdf`) ;
        exportFile(doc, pdfPath, usePdfx ? 'pdfx4' : 'pdf') ;
        written.push([pdfPath, usePdfx ? 'PDF/X-4' : 'PDF']) ;
    }

    // 2. ラスターと CMYK：対象の図の PDF を開き直した文書で、dpi と色形式を変えて書き出す
    if (formats.includes('png') || formats.includes('tiff') || useCmyk) {
        const sourcePdf = joinPath(workDir, `export_source_${title}.pdf`) ;
        exportFile(doc, sourcePdf, 'pdf') ;
        const source = Document.load(sourcePdf) ;
        try {
            const properties = DocumentProperties.create() ;
            properties.setDpi(dpi) ;
            source.setDocumentProperties(properties) ;
            if (useCmyk) {
                source.format = RasterFormat.CMYKA8 ;
                if (formats.includes('pdf')) {
                    const pdfPath = joinPath(exportDir, `${baseName}_cmyk.pdf`) ;
                    exportFile(source, pdfPath, usePdfx ? 'pdfx4' : 'pdfPress') ;
                    written.push([pdfPath, 'PDF（CMYK）']) ;
                }
            }
            if (formats.includes('png')) {
                const pngPath = joinPath(exportDir, `${baseName}_${dpi}dpi.png`) ;
                exportFile(source, pngPath, 'png') ;
                written.push([pngPath, 'PNG']) ;
            }
            if (formats.includes('tiff')) {
                const tiffPath = joinPath(exportDir, `${baseName}_${dpi}dpi${useCmyk ? '_cmyk' : ''}.tif`) ;
                exportFile(source, tiffPath, useCmyk ? 'tiffCmyk' : 'tiff') ;
                written.push([tiffPath, useCmyk ? 'TIFF（CMYK）' : 'TIFF']) ;
            }
        } finally {
            source.close() ;
        }
        console.log(`[--] 途中のファイル：${sourcePdf}（確認の後に削除する）`) ;
    }

    // 3. 確認
    for (const [path, label] of written) {
        verify(path, label) ;
    }
}

const title = globalThis.exportTitle ;
const formats = String(globalThis.formats ?? 'pdf,png').split(',').map((item) => item.trim().toLowerCase()).filter((item) => item) ;
const dpi = Number(globalThis.dpi ?? 600) ;
const usePdfx = String(globalThis.pdfx ?? 'false') === 'true' ;
const useCmyk = String(globalThis.cmyk ?? 'false') === 'true' ;
const doc = app.documents.all.find((item) => item.title === title) ;
const unknown = formats.filter((item) => !['pdf', 'png', 'tiff'].includes(item)) ;
if (!title || !doc) {
    console.log(`[NG] 対象の図が開いていない（exportTitle=${title}）。開いている文書：${app.documents.all.map((item) => item.title).join(', ')}`) ;
} else if (unknown.length > 0) {
    console.log(`[NG] 知らない形式：${unknown.join(', ')}（pdf、png、tiff のどれか）`) ;
} else {
    const dirtyBefore = doc.isDirty ;
    // 対象の図の保存場所（読み取りだけ）。デスクトップの作業フォルダの .af は、組み立て直すと上書きされる
    // 保存場所の取得に失敗しても、書き出しは止めない（未保存の新規の図での動作は未確認のため）
    let documentPath = '' ;
    try {
        documentPath = String(doc.path ?? '') ;
    } catch (error) {
        console.log(`[file] 保存場所を取得できなかった：${error.message}`) ;
    }
    const insideWorkDir = documentPath !== '' && documentPath.toLowerCase().startsWith(workDir.toLowerCase()) ;
    console.log(`[file] 対象の図の保存場所：${documentPath === '' ? '（保存されていない）' : documentPath}`
        + `${insideWorkDir ? '（デスクトップの作業フォルダの中。組み立て直すと上書きされ、研究のフォルダには残らない）' : ''}`) ;
    exportFigure(doc, title, formats, dpi, usePdfx, useCmyk) ;
    console.log(`[summary] ${title}：${formats.join(', ')} を書き出した（dpi ${dpi}${usePdfx ? '、PDF/X-4' : ''}${useCmyk ? '、CMYK' : ''}）。`
        + `対象の図の未保存の変更は、書き出しの前 ${dirtyBefore ? 'あり' : 'なし'}、後 ${doc.isDirty ? 'あり' : 'なし'}`) ;
}
