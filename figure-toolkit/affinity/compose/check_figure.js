// 組み立てた図の確認（読み取りだけ。図のドキュメントは変更しない。2026-10-19）
//
// 対象：Affinity で開いている図。globalThis.checkFigureTitles（題名の配列、またはカンマ区切りの文字列）で指定する。
//       省略時は、最初の見開きの最上位に Figure area レイヤーがある、開いているすべてのドキュメント。
// 確認する項目（行の先頭の [OK]・[NG]・[--] が判定。[--] は判定しない情報）：
//   1. page      ページの大きさが Figure area の矩形と同じか。パネルとパネル記号がページに収まっているか
//   2. layers    最上位のレイヤーの順と、パネルごとのサブレイヤー（要素の数）
//   3. position  パネルごとに、取り込んだ要素（annotations を除く）を Notes の比較用の全体図（MATLAB の書き出しのまま）の要素と
//                対応させ、位置の差の最大が 0.5 mm 以下か。対応の取れない要素がないか
//                （文字のまとまりが比較用の全体図と違うもの（組み立てで目盛りごとに分けた文字、取り込みで 1 つの文字が 2 つに分かれたものなど）は、
//                 語が全体図の文字に含まれていれば対応とみなし、位置は比べない）
//   4. text      まとまり（目盛り、軸ラベル、凡例、注釈、パネル記号、その他）ごとのフォントと大きさ。
//                まとまりの中で大きさが揃っているか、パネル記号 > 軸ラベル > 目盛り の大小関係か（docs/figure-panel-style.md の 2 節）
//   5. lines     パネルごとの線幅
//   6. export    最初のページを PDF に書き出して開き直し、ページの大きさと、文字の数が表示中の文字の数と同じか
//                （非表示の Notes が含まれていないか）。書き出した PDF は affinity_mcp_work/check_<題名>.pdf に残るので、
//                確認の後に削除する（docs/figure-style.md の「原案の作図スクリプトから図を作る」）
// 実行（figure-toolkit のフォルダで）：
//   node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=<題名>（複数はカンマ区切り）
// 最後に [summary] の行で、NG の項目の数を出す。

const { app } = require('/application') ;
const { Document, FileExportOptions, FileExportArea } = require('/document') ;
// PDF の書き出しのプリセット「書き出し用」の名前（Affinity の表示の言語で変わるので、日本語と英語の名前、なければ名前の形で探す）
const pdfExportPresetName = ['PDF(書き出し用)', 'PDF (for export)'].find((name) => FileExportOptions.allPresetNames.includes(name))
    ?? FileExportOptions.allPresetNames.find((name) => /^PDF.*(書き出し|export)/i.test(name)) ;

const pathSeparator = app.userDesktopPath.includes('\\') ? '\\' : '/' ;
const joinPath = (...parts) => parts.join(pathSeparator) ;
const workDir = joinPath(app.userDesktopPath, 'affinity_mcp_work') ;
const positionToleranceMm = 0.5 ; // 比較用の全体図との位置の差の許容 [mm]（比較用の 1 ページ目の高さの違いで約 0.35 mm の差が出る）

// サブレイヤー名の「成分」（panel_style_tool.js と同じ。長いものから順に照合する）
const componentKinds = [
    'confidence band', 'tick labels', 'axis labels', 'axes lines', 'error bars', 'fit line',
    'annotations', 'legend', 'markers', 'events', 'lines', 'bands', 'bars',
] ;
const textCategoryOf = (kind) => ({ 'tick labels': 'tick labels', 'axis labels': 'axis labels', legend: 'legend', annotations: 'annotations' }[kind] ?? 'other') ;


// ---------------------------------------------------------------
// 共通の関数
// ---------------------------------------------------------------

function collectNodes(node, list) {
    for (const child of node.children.toArray()) {
        list.push(child) ;
        collectNodes(child, list) ;
    }
    return list ;
}

function transformScale(transform) {
    const parts = transform.decompose() ;
    return (Math.abs(parts.scaleX) + Math.abs(parts.scaleY))/2 ;
}

function unionBox(boxes) {
    const left = Math.min(...boxes.map((box) => box.x)) ;
    const top = Math.min(...boxes.map((box) => box.y)) ;
    const right = Math.max(...boxes.map((box) => box.x + box.width)) ;
    const bottom = Math.max(...boxes.map((box) => box.y + box.height)) ;
    return { x: left, y: top, width: right - left, height: bottom - top } ;
}

function kindOf(name, panel) {
    const prefix = `${panel}: ` ;
    if (!name || !name.startsWith(prefix)) {
        return null ;
    }
    const rest = name.slice(prefix.length) ;
    return componentKinds.find((candidate) => rest === candidate || rest.startsWith(`${candidate} `)) ?? rest ;
}

// 位置の比較に使う要素の特徴（compose_single_panels.js の手順 3 と同じ）：種類・塗りと線の色、文字は内容
function signature(node) {
    const box = node.getSpreadVisibleBox() ;
    const colour = (descriptor) => {
        const fill = descriptor?.fill ;
        return fill && fill.colour ? `${fill.colour.rgba8.r},${fill.colour.rgba8.g},${fill.colour.rgba8.b}` : '-' ;
    } ;
    const label = node.isTextNode
        ? `text "${node.text.trim()}"`
        : `${node.constructor.name} fill=${node.hasBrushFill ? colour(node.brushFillDescriptor) : '-'} line=${node.hasPenFill && node.lineWeight > 0 ? colour(node.penFillDescriptor) : '-'}` ;
    return { box, label, text: node.isTextNode ? node.text.trim() : null } ;
}
const isDrawn = (node) => node.isVectorNode || node.isTextNode ;

// 文字の大きさ [pt]（見た目の大きさ）とフォント名
function textRuns(node, dpi) {
    return node.story.getGlyphAttRunsFrom(0).toArray().map((run) => ({
        family: run.glyphAtts.font.familyName,
        sizePt: Number((run.glyphAtts.height*transformScale(node.baseToSpreadTransform)*72/dpi).toFixed(2)),
    })) ;
}


// ---------------------------------------------------------------
// 1 つの図の確認
// ---------------------------------------------------------------

function checkFigure(doc) {
    const pxPerMm = doc.dpi/25.4 ;
    const mm = (px) => (px/pxPerMm).toFixed(2) ;
    const spread = doc.spreads.toArray()[0] ;
    const topLayers = spread.children.toArray() ;
    const layerNamed = (name) => topLayers.find((layer) => layer.userDescription === name) ;
    const results = [] ;
    const report = (status, item, message) => {
        results.push(status) ;
        console.log(`[${status}] ${item}: ${message}`) ;
    } ;
    console.log(`== ${doc.title}（uuid=${doc.sessionUuid}、ページ ${doc.spreads.toArray().length}）`) ;

    // 1. ページと Figure area
    const pageBox = spread.getSpreadBaseBox() ;
    const areaRect = layerNamed('Figure area')?.children.toArray()[0] ;
    const panelLayers = topLayers.filter((layer) => /^Panel \S+$/.test(layer.userDescription ?? '')) ;
    const labelsLayer = layerNamed('Labels') ;
    if (areaRect) {
        const rectBox = areaRect.getSpreadBaseBox() ;
        const sameSize = Math.abs(rectBox.width - pageBox.width) < 0.01*pxPerMm && Math.abs(rectBox.height - pageBox.height) < 0.01*pxPerMm
            && Math.abs(rectBox.x - pageBox.x) < 0.01*pxPerMm && Math.abs(rectBox.y - pageBox.y) < 0.01*pxPerMm ;
        report(sameSize ? 'OK' : 'NG', 'page', `ページ ${mm(pageBox.width)} x ${mm(pageBox.height)} mm、${areaRect.userDescription}`) ;
    } else {
        report('NG', 'page', 'Figure area の矩形がない') ;
    }
    const contentLayers = [...panelLayers, ...(labelsLayer ? [labelsLayer] : [])] ;
    if (contentLayers.length > 0) {
        const content = unionBox(contentLayers.map((layer) => layer.getSpreadVisibleBox())) ;
        const inside = content.x >= pageBox.x - 0.01*pxPerMm && content.y >= pageBox.y - 0.01*pxPerMm
            && content.x + content.width <= pageBox.x + pageBox.width + 0.01*pxPerMm
            && content.y + content.height <= pageBox.y + pageBox.height + 0.01*pxPerMm ;
        report(inside ? 'OK' : 'NG', 'page', `内容の範囲 x ${mm(content.x - pageBox.x)}〜${mm(content.x + content.width - pageBox.x)} mm、`
            + `y ${mm(content.y - pageBox.y)}〜${mm(content.y + content.height - pageBox.y)} mm（ページに${inside ? '収まる' : '収まらない'}）`) ;
    }

    // 2. レイヤーの構成（前面から）
    report('--', 'layers', topLayers.slice().reverse().map((layer) => layer.userDescription).join(' > ')) ;
    for (const panelLayer of panelLayers.slice().reverse()) {
        const panel = panelLayer.userDescription.slice('Panel '.length) ;
        const subLayers = panelLayer.children.toArray().slice().reverse() ;
        report('--', 'layers', `${panelLayer.userDescription}：${subLayers.map((layer) => `${(layer.userDescription ?? '').slice(panel.length + 2)}(${layer.children.toArray().length})`).join(', ')}`) ;
    }

    // 3. 位置：比較用の全体図との対応
    const notesLayer = layerNamed('Notes') ;
    const referenceLayers = notesLayer ? notesLayer.children.toArray() : [] ;
    for (const panelLayer of panelLayers) {
        const panel = panelLayer.userDescription.slice('Panel '.length) ;
        const referenceLayer = referenceLayers.find((layer) => layer.userDescription === `reference ${panel} (MATLAB full figure)`)
            ?? (panelLayers.length === 1 ? referenceLayers.find((layer) => layer.userDescription === 'reference (MATLAB full figure)') : null) ;
        if (!referenceLayer) {
            report('NG', 'position', `Panel ${panel}：比較用の全体図がない`) ;
            continue ;
        }
        const referenceItems = collectNodes(referenceLayer, []).filter(isDrawn).map(signature) ;
        const composedItems = panelLayer.children.toArray()
            .filter((layer) => kindOf(layer.userDescription, panel) !== 'annotations')
            .flatMap((layer) => collectNodes(layer, []))
            .filter(isDrawn).map(signature) ;
        let maxOffset = 0 ;
        let maxOffsetLabel = '-' ;
        let matched = 0 ;
        let regroupedText = 0 ;
        // 全体図の文字を、取り込んだ順に空白を除いてつないだもの（文字のまとまりの違いの照合に使う）
        const compact = (text) => text.replace(/\s+/g, '') ;
        const referenceTextJoined = referenceItems.filter((ref) => ref.text !== null).map((ref) => compact(ref.text)).join('') ;
        const unmatched = [] ;
        for (const item of composedItems) {
            const isText = item.text !== null ;
            const candidates = referenceItems.filter((ref) => ref.label === item.label
                && (isText || (Math.abs(ref.box.width - item.box.width) < 2 && Math.abs(ref.box.height - item.box.height) < 2))) ;
            if (candidates.length === 0) {
                // 文字のまとまりの違い：この文字（空白を除く）が、全体図の文字をつないだものに含まれていれば対応とみなす
                // （組み立てで目盛りごとに分けた文字、取り込みで全体図の 1 つの文字が 2 つに分かれたものなど。Affinity の PDF の取り込みでは、
                //   同じ文字でもページによってまとまり方が違うことがある：2026-10-19、縦軸のラベルが "V" と "ertical GRF (BW)" に分かれた）
                if (isText && compact(item.text) !== '' && referenceTextJoined.includes(compact(item.text))) {
                    regroupedText += 1 ;
                } else {
                    unmatched.push(item.label) ;
                }
                continue ;
            }
            // 文字は外枠の大きさが異なることがあるので、左端・中央・右端（縦も上端・中央・下端）のうち最も近いものの差を取る
            const fractions = isText ? [0, 0.5, 1] : [0] ;
            const edgeOffset = (ref, key, sizeKey) => Math.min(...fractions.map((fraction) =>
                Math.abs((ref.box[key] + fraction*ref.box[sizeKey]) - (item.box[key] + fraction*item.box[sizeKey])))) ;
            const offset = Math.min(...candidates.map((ref) => Math.hypot(edgeOffset(ref, 'x', 'width'), edgeOffset(ref, 'y', 'height')))) ;
            if (offset > maxOffset) {
                maxOffset = offset ;
                maxOffsetLabel = item.label ;
            }
            matched += 1 ;
        }
        const ok = unmatched.length === 0 && maxOffset/pxPerMm <= positionToleranceMm ;
        report(ok ? 'OK' : 'NG', 'position', `Panel ${panel}：要素 ${composedItems.length}（対応 ${matched}、まとまりの違う文字 ${regroupedText}、対応なし ${unmatched.length}）、`
            + `位置の差の最大 ${(maxOffset/pxPerMm).toFixed(3)} mm（${maxOffsetLabel}）`) ;
        if (unmatched.length > 0) {
            console.log(`       対応なし：${unmatched.slice(0, 10).join(' | ')}${unmatched.length > 10 ? ' …' : ''}`) ;
        }
    }

    // 4. 文字：まとまりごとのフォントと大きさ
    const categories = new Map() ; // まとまり → Map('フォント 大きさ' → 数)
    const sizesOf = new Map() ; // まとまり → 大きさの集合
    const addText = (category, node) => {
        for (const run of textRuns(node, doc.dpi)) {
            const key = `${run.family} ${run.sizePt.toFixed(2)}pt` ;
            const counts = categories.get(category) ?? new Map() ;
            counts.set(key, (counts.get(key) ?? 0) + 1) ;
            categories.set(category, counts) ;
            sizesOf.set(category, (sizesOf.get(category) ?? new Set()).add(run.sizePt)) ;
        }
    } ;
    for (const panelLayer of panelLayers) {
        const panel = panelLayer.userDescription.slice('Panel '.length) ;
        for (const subLayer of panelLayer.children.toArray()) {
            const category = textCategoryOf(kindOf(subLayer.userDescription, panel)) ;
            collectNodes(subLayer, []).filter((node) => node.isTextNode).forEach((node) => addText(category, node)) ;
        }
    }
    if (labelsLayer) {
        collectNodes(labelsLayer, []).filter((node) => node.isTextNode).forEach((node) => addText('panel labels', node)) ;
    }
    for (const [category, counts] of categories) {
        const uniform = ['tick labels', 'axis labels', 'legend', 'panel labels'].includes(category) ? sizesOf.get(category).size === 1 : true ;
        report(uniform ? 'OK' : 'NG', 'text', `${category}：${[...counts].map(([key, count]) => `${key} × ${count}`).join(', ')}${uniform ? '' : '（大きさが揃っていない）'}`) ;
    }
    const largest = (category) => (sizesOf.has(category) ? Math.max(...sizesOf.get(category)) : null) ;
    const smallest = (category) => (sizesOf.has(category) ? Math.min(...sizesOf.get(category)) : null) ;
    const order = [['panel labels', 'axis labels'], ['axis labels', 'tick labels']]
        .filter(([larger, smaller]) => sizesOf.has(larger) && sizesOf.has(smaller))
        .map(([larger, smaller]) => ({ larger, smaller, ok: smallest(larger) > largest(smaller) })) ;
    if (order.length > 0) {
        report(order.every((pair) => pair.ok) ? 'OK' : 'NG', 'text', `大小関係：${order.map((pair) => `${pair.larger} > ${pair.smaller}${pair.ok ? '' : '（逆）'}`).join('、')}`) ;
    }

    // 5. 線幅
    for (const panelLayer of panelLayers) {
        const weights = new Set(collectNodes(panelLayer, [])
            .filter((node) => node.isVectorNode && node.hasPenFill && node.lineWeight > 0)
            .map((node) => (node.lineWeight*transformScale(node.localToSpreadTransform)*72/doc.dpi).toFixed(2))) ;
        report('--', 'lines', `${panelLayer.userDescription}：${[...weights].sort().join(', ')} pt`) ;
    }

    // 6. 書き出した PDF
    const visibleTextCount = contentLayers.flatMap((layer) => collectNodes(layer, [])).filter((node) => node.isTextNode).length ;
    const checkPdf = joinPath(workDir, `check_${doc.title}.pdf`) ;
    const records = doc.export(checkPdf, FileExportOptions.createWithPresetName(pdfExportPresetName), FileExportArea.createForPages('1')) ;
    if (!records.all.every((record) => record.isSuccess)) {
        report('NG', 'export', `書き出しに失敗：${records.all.map((record) => record.errorMessage).join(', ')}`) ;
    } else {
        const exported = Document.load(checkPdf) ;
        const exportedSpread = exported.spreads.toArray()[0] ;
        const exportedBox = exportedSpread.getSpreadBaseBox() ;
        const exportedNodes = collectNodes(exportedSpread, []) ;
        const exportedTextCount = exportedNodes.filter((node) => node.isTextNode).length ;
        const exportedPxPerMm = exported.dpi/25.4 ;
        const sameSize = Math.abs(exportedBox.width/exportedPxPerMm - pageBox.width/pxPerMm) < 0.1
            && Math.abs(exportedBox.height/exportedPxPerMm - pageBox.height/pxPerMm) < 0.1 ;
        report(sameSize && exportedTextCount === visibleTextCount ? 'OK' : 'NG', 'export',
            `PDF ${(exportedBox.width/exportedPxPerMm).toFixed(1)} x ${(exportedBox.height/exportedPxPerMm).toFixed(1)} mm、`
            + `文字 ${exportedTextCount}（表示中 ${visibleTextCount}）、図形 ${exportedNodes.filter((node) => node.isVectorNode).length}。確認用の PDF：${checkPdf}`) ;
        exported.close() ;
    }

    const ngCount = results.filter((status) => status === 'NG').length ;
    console.log(`[summary] ${doc.title}：NG ${ngCount} 件`) ;
}


// ---------------------------------------------------------------
// 実行
// ---------------------------------------------------------------

const wantedTitles = typeof globalThis.checkFigureTitles === 'string' ? globalThis.checkFigureTitles.split(',').map((title) => title.trim()) : globalThis.checkFigureTitles ;
const isComposedFigure = (doc) => doc.spreads.toArray()[0]?.children.toArray().some((layer) => layer.userDescription === 'Figure area') ;
const targets = app.documents.all.filter((doc) => (wantedTitles ? wantedTitles.includes(doc.title) : isComposedFigure(doc))) ;
if (targets.length === 0) {
    console.log(`[summary] 対象の図が開いていない（${wantedTitles ? `題名 ${wantedTitles.join(', ')}` : 'Figure area のある図'}）`) ;
}
for (const doc of targets) {
    try {
        checkFigure(doc) ;
    } catch (error) {
        console.log(`[NG] ${doc.title}: 確認の途中で例外 ${error.message}\n${error.stack}`) ;
    }
}
