// 単一パネルの図を組み立てる：成分ごとのページを重ねてサブレイヤーにし、注釈を加えて書き出す
//
// 入力：デスクトップの affinity_mcp_work/input/panels/ の <name>.json と <name>_components.pdf（または 1 ページに並べた <name>_components_stacked.pdf）
//       （MATLAB の exportPanel.m で作る。例：figure-types/make_all_examples.m。JSON にページとサブレイヤーの対応、注釈の指定がある）
// 手順（docs/figure-panel-style.md の 4・5 節）：
//   1. 成分ごとのページの PDF を開く。JSON に stackedPdf があれば（tools/stack_component_pages.py で作る）、1 ページに並べた PDF を開き、
//      ページごとの領域の要素を一時的なレイヤー（page N）に入れて元の位置へ戻し、ページの代わりに使う
//   2. 最後のページの位置合わせ用の点 2 つから、データ座標 → ページ上の位置 [px] の対応を求める
//   3. 成分のページの要素と、1 ページ目の全体の図（比較用）の要素の位置を比べる
//   4. 取り込んだ文字の揃えを、JSON の指定（成分ごと）に合わせてページごとに設定する（Affinity で文字を直したときに基準の位置が保たれるように）：
//      縦軸の目盛りは右揃え、凡例は左揃え、横軸の目盛り・軸ラベル・タイトルは中央揃え、指定のないイベント線の名前は線の側に揃える。
//      揃えを変えると位置が少し動くので、基準の点（左端・中央・右端）を元の位置へ戻す。あわせて、MATLAB の文字送りを再現するための
//      1 文字ごとの字間（CharacterSpacing）を 0 に戻す（手で文字を打ち直したときに不揃いな字間が残らないように）。
//      取り込み時に 1 つの文字にまとまった横軸の目盛り（例："-250 -200 -150 -100"）は、目盛りごとの文字に分ける
//   5. 1 ページ目に Panel A を作り、2 ページ目以降の要素を JSON の順にサブレイヤーへ移す（背面から前面の順）。
//      軸は axes lines（軸線・目盛り線）、tick labels（目盛りの文字）、axis labels（軸ラベル・タイトル）に分かれる。
//      全体の図は Notes の中の reference に移して非表示にする
//   6. 位置合わせ用の点と一時的なレイヤーを削除する。複数ページの PDF から組み立てたときは、ページは SDK では削除できない（3.3.1）ので、
//      2 ページ目以降が空のページとして残る（1 ページに並べた PDF から組み立てれば残らない）
//   7. 注釈を A: annotations に加える（文字の大きさは取り込んだ目盛りの文字に合わせ、揃えは置き方の基準に合わせる）
//   8. 文字・線幅を集計し、.af を保存し、PDF と PNG を書き出す。書き出した PDF を開き直して要素の数を確かめる
// 出力：affinity_mcp_work/panels/<name>.af（開いたまま残す）、affinity_mcp_work/export/<name>.pdf・.png（クライアントが移す）
// 実行（figure-toolkit のフォルダで）：AFFINITY_COLLECT_DIR=<移す先の絶対パス> node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js
//       引数（--set）：panelNames=jump_height（複数はカンマ区切り）でその図だけを処理する。inputFolder=<フォルダ名> で入力を input/<フォルダ名> にする

const { app } = require('/application') ;
const { Document, FileExportOptions, FileExportArea, SpatialAnchor } = require('/document') ;
const { AddChildNodesCommandBuilder, DocumentCommand, NodeMoveType } = require('/commands') ;
const { ArtTextNodeDefinition, ContainerNodeDefinition, PolyCurveNodeDefinition, ShapeNodeDefinition, NodeChildType } = require('/nodes') ;
const { ShapeRectangle } = require('/shapes') ;
const { CurveBuilder, PolyCurve, Point, Rectangle, Transform } = require('/geometry') ;
const { FillDescriptor } = require('/fills') ;
const { ArrowHead, ArrowHeadStyle, LineStyle, LineStyleDescriptor } = require('/linestyle') ;
const { Selection, TextSelection } = require('/selections') ;
const { StoryBuilder } = require('/storybuilder') ;
const { StoryDelta } = require('/storydelta') ;
const { GlyphAttDoubleType } = require('/glyphatts') ;
const { ParagraphAlignXType } = require('/paragraphatts') ;
const { Colour } = require('/colours') ;
const { File, DirectoryIterator, fs } = require('/fs') ;
// PDF の書き出しのプリセット「書き出し用」の名前（Affinity の表示の言語で変わるので、日本語と英語の名前、なければ名前の形で探す）
const pdfExportPresetName = ['PDF(書き出し用)', 'PDF (for export)'].find((name) => FileExportOptions.allPresetNames.includes(name))
    ?? FileExportOptions.allPresetNames.find((name) => /^PDF.*(書き出し|export)/i.test(name)) ;

// パスの区切り：Windows は \、Mac は /（デスクトップの場所の書き方から判断する）
const pathSeparator = app.userDesktopPath.includes('\\') ? '\\' : '/' ;
const joinPath = (...parts) => parts.join(pathSeparator) ;
const workDir = joinPath(app.userDesktopPath, 'affinity_mcp_work') ;
// MATLAB の書き出し先：affinity_mcp_work/input/<inputFolder>（既定 panels。figure-types の例は input/panels に書き出す）
const inputDir = joinPath(workDir, 'input', globalThis.inputFolder ?? 'panels') ;
const exportDir = joinPath(workDir, 'export') ;
const savedDir = joinPath(workDir, 'panels') ; // .af の保存先（クライアントが移さない場所に置き、開いたドキュメントの保存先を保つ）
const black = Colour.createRGBA8({ r: 0, g: 0, b: 0, alpha: 255 }) ;


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

function boxCentre(node) {
    const box = node.getSpreadVisibleBox() ;
    return { x: box.x + box.width/2, y: box.y + box.height/2 } ;
}

// 入力フォルダの JSON（図の構成）を読む
function readSpecs() {
    const specs = [] ;
    const iterator = DirectoryIterator.at(inputDir) ;
    while (!iterator.isDone()) {
        const path = iterator.path ;
        if (/\.json$/.test(path)) {
            specs.push(JSON.parse(File.readAll(path).toString())) ;
        }
        iterator.next() ;
    }
    const wanted = typeof globalThis.panelNames === 'string' ? globalThis.panelNames.split(',').map((name) => name.trim()) : globalThis.panelNames ;
    return specs
        .filter((spec) => !wanted || wanted.includes(spec.name))
        .sort((a, b) => (a.name < b.name ? -1 : 1)) ; // localeCompare は Affinity の V8 で ICU のエラーになる
}


// ---------------------------------------------------------------
// 1 つの図の組み立て
// ---------------------------------------------------------------

function composePanel(spec) {
    const sourceTitle = spec.componentsPdf ;

    // 前回の実行で開いた同じ図のドキュメントは閉じる（.af で保存した後の題名は拡張子なし）。保存していない変更があれば止める
    for (const openDoc of app.documents.all) {
        if (openDoc.title === sourceTitle || openDoc.title === spec.stackedPdf || openDoc.title === spec.name) {
            // 保存していない変更がある文書は閉じない（ユーザーが Affinity で手を加えた可能性がある。変更が失われないように止める）
            // 同じ名前で保存してもらうと、下の saveAs が affinity_mcp_work/panels/<名前>.af を上書きするので、別の名前で保存してもらう
            if (openDoc.isDirty) {
                throw new Error(`「${openDoc.title}」に保存していない変更があるため、閉じずに止めた。変更を残す場合は、Affinity で別の名前で保存して閉じる`
                    + `（同じ名前で保存すると、組み立て直したときに affinity_mcp_work/panels/${spec.name}.af が上書きされる）。`
                    + `残さない場合は、変更を破棄して閉じる。その後、もう一度実行する`) ;
            }
            openDoc.close() ;
        }
    }
    const doc = Document.load(joinPath(inputDir, spec.stackedPdf ?? spec.componentsPdf)) ;
    const pxPerMm = doc.dpi/25.4 ;
    const pxPerPt = doc.dpi/72 ;
    const spreads = doc.spreads.toArray() ;
    const firstSpread = spreads[0] ;
    console.log(`== ${spec.name}: uuid=${doc.sessionUuid}, pages=${spreads.length}, dpi=${doc.dpi}`) ;

    // ---- 文書の操作 ----
    function executeAndGetNode(builder) {
        const command = builder.createCommand(false, NodeChildType.Main) ;
        doc.executeCommand(command) ;
        return command.newNodes[0] ;
    }
    // 親（見開きまたはレイヤー）の中に名前付きのレイヤーを作る（最前面に入る）
    function addLayer(parent, name) {
        const builder = AddChildNodesCommandBuilder.create() ;
        builder.setInsertionTarget(parent) ;
        builder.addNode(ContainerNodeDefinition.create(name)) ;
        return executeAndGetNode(builder) ;
    }
    // 別ページの要素を、移動元のページを現在の見開きにしてからレイヤーへ移す（開発時の試行 I4）
    function moveInto(nodes, sourceSpread, layer) {
        if (nodes.length === 0) {
            return ;
        }
        doc.executeCommand(DocumentCommand.createSetCurrentSpread(sourceSpread)) ;
        doc.executeCommand(DocumentCommand.createMoveNodes(Selection.create(doc, nodes), layer, NodeMoveType.Inside, NodeChildType.Main)) ;
    }

    // ---- 1. 成分のページ ----
    // 1 ページに並べた PDF（tools/stack_component_pages.py の出力。JSON の stackedPages）のときは、ページごとの領域にある要素を
    // 一時的なレイヤー（page N）に入れて元のページの位置（左上が原点）へ戻し、そのレイヤーをページの代わりに使う。
    // 一時的なレイヤーは最後に削除するので、.af に空のページが残らない。
    // 複数ページの PDF のとき（stackedPages がない）は、見開きをそのまま使う（2 ページ目以降は空のページとして残る）
    function openComponentPages(stacked) {
        if (!stacked) {
            return { pageParents: spreads, spreadOfPage: (index) => spreads[index], temporaryLayers: [] } ;
        }
        const { columns, gapPt, cellSizePt, offsetsPt } = stacked ;
        const groups = offsetsPt.map(() => []) ;
        for (const node of firstSpread.children.toArray()) {
            const box = node.getSpreadVisibleBox() ;
            const column = Math.min(columns - 1, Math.max(0, Math.floor((box.x + box.width/2)/((cellSizePt[0] + gapPt)*pxPerPt)))) ;
            const row = Math.max(0, Math.floor((box.y + box.height/2)/((cellSizePt[1] + gapPt)*pxPerPt))) ;
            const index = row*columns + column ;
            if (index >= groups.length) {
                throw new Error(`1 ページに並べた PDF の要素が、どのページの領域にも入らない（行 ${row + 1}、列 ${column + 1}）`) ;
            }
            groups[index].push(node) ;
        }
        const layers = groups.map((nodes, index) => {
            const layer = addLayer(firstSpread, `page ${index + 1}`) ;
            if (nodes.length > 0) {
                moveInto(nodes, firstSpread, layer) ;
                const [left, top] = offsetsPt[index] ;
                doc.executeCommand(DocumentCommand.createTransform(Selection.create(doc, nodes), Transform.createTranslate(-left*pxPerPt, -top*pxPerPt))) ;
            }
            return layer ;
        }) ;
        console.log(`[pages] stacked PDF: ${offsetsPt.length} pages (${groups.map((nodes) => nodes.length).join(', ')} nodes)`) ;
        return { pageParents: layers, spreadOfPage: () => firstSpread, temporaryLayers: layers } ;
    }
    // 一時的なレイヤー（page N）を削除する（要素が残っていれば削除せず、知らせる）
    function removeTemporaryLayers(layers) {
        const remaining = layers.filter((layer) => layer.children.toArray().length > 0) ;
        if (remaining.length > 0) {
            console.log(`[pages] 一時的なレイヤーに要素が残った：${remaining.map((layer) => `${layer.userDescription}(${layer.children.toArray().length})`).join(', ')}`) ;
        }
        const empty = layers.filter((layer) => layer.children.toArray().length === 0) ;
        if (empty.length > 0) {
            doc.deleteSelection(Selection.create(doc, empty)) ;
        }
    }
    const { pageParents, spreadOfPage, temporaryLayers } = openComponentPages(spec.stackedPages) ;
    const pageNodes = pageParents.map((parent) => parent.children.toArray()) ; // 開いたときの各ページの要素

    // ---- 2. データ座標 → ページ上の位置 [px]：位置合わせ用の点 2 つの外枠の中心から 1 次式を求める ----
    const calibrationNodes = pageNodes[spec.calibration.page - 1] ;
    if (calibrationNodes.length !== 2) {
        throw new Error(`${spec.name}: 位置合わせ用のページの要素が ${calibrationNodes.length} 個（2 個のはず）`) ;
    }
    const measured = calibrationNodes.map(boxCentre).sort((a, b) => a.x - b.x) ; // データの x が小さい点が左
    const [dataLow, dataHigh] = spec.calibration.points ;
    const xScale = (measured[1].x - measured[0].x)/(dataHigh[0] - dataLow[0]) ;
    const yScale = (measured[1].y - measured[0].y)/(dataHigh[1] - dataLow[1]) ; // ページの y は下向きなので負になる
    const toPage = (x, y) => new Point(measured[0].x + xScale*(x - dataLow[0]), measured[0].y + yScale*(y - dataLow[1])) ;
    // 確認：MATLAB で指定した軸の枠の幅・高さと比べる
    const axisWidthMm = Math.abs(xScale*(spec.xlim[1] - spec.xlim[0]))/pxPerMm ;
    const axisHeightMm = Math.abs(yScale*(spec.ylim[1] - spec.ylim[0]))/pxPerMm ;
    console.log(`[map] axis box from calibration: ${axisWidthMm.toFixed(2)} x ${axisHeightMm.toFixed(2)} mm `
        + `(MATLAB InnerPosition: ${(spec.innerPositionCm[2]*10).toFixed(2)} x ${(spec.innerPositionCm[3]*10).toFixed(2)} mm)`) ;

    // ---- 3. 重ねる前の確認：成分のページ（2 ページ目〜位置合わせの前）の要素と、1 ページ目の全体の図の要素の位置の差 ----
    // 種類・色・大きさが同じ要素どうしを対応させる。文字は内容だけで対応を取る
    // （比較用の 1 ページ目は MATLAB の 1 回目の書き出しで、文字の外枠の幅が他のページと異なるため）
    function signature(node) {
        const box = node.getSpreadVisibleBox() ;
        const colour = (descriptor) => {
            const fill = descriptor?.fill ;
            return fill && fill.colour ? `${fill.colour.rgba8.r},${fill.colour.rgba8.g},${fill.colour.rgba8.b}` : '-' ;
        } ;
        const label = node.isTextNode
            ? `text "${node.text.trim()}"`
            : `${node.constructor.name} fill=${node.hasBrushFill ? colour(node.brushFillDescriptor) : '-'} line=${node.hasPenFill && node.lineWeight > 0 ? colour(node.penFillDescriptor) : '-'}` ;
        return { box, label } ;
    }
    const isDrawn = (node) => node.isVectorNode || node.isTextNode ;
    const referenceItems = pageNodes[0].filter(isDrawn).map(signature) ;
    const composedItems = spec.pages.flatMap((page) => pageNodes[page.page - 1]).filter(isDrawn).map(signature) ;
    let maxOffset = 0 ;
    let maxOffsetLabel = '-' ;
    let matched = 0 ;
    const unmatched = [] ;
    for (const item of composedItems) {
        const isText = item.label.startsWith('text ') ;
        const candidates = referenceItems.filter((ref) => ref.label === item.label
            && (isText || (Math.abs(ref.box.width - item.box.width) < 2 && Math.abs(ref.box.height - item.box.height) < 2))) ;
        if (candidates.length === 0) {
            unmatched.push(item.label) ;
            continue ;
        }
        // 文字は外枠の大きさが異なるので、左端・中央・右端（縦も上端・中央・下端）のうち最も近いものの差を取る
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
    console.log(`[align] reference=${referenceItems.length}, composed=${composedItems.length}, matched=${matched}, `
        + `max offset=${(maxOffset/pxPerMm).toFixed(3)} mm (${maxOffsetLabel})`) ;
    if (unmatched.length > 0) {
        console.log(`[align] not matched: ${unmatched.join(' | ')}`) ;
    }

    // ---- 4. 文字の揃え（サブレイヤーへ移す前に、ページごとに行う）----
    const textSizePt = (node) => node.story.getGlyphAtts(0).height*transformScale(node.baseToSpreadTransform)*72/doc.dpi ;
    const alignTypes = { left: ParagraphAlignXType.Left, center: ParagraphAlignXType.Centre, right: ParagraphAlignXType.Right } ;
    const axisOrigin = toPage(spec.xlim[0], spec.ylim[0]) ; // 軸の枠の左下 [px]
    // ページの要素から、サブレイヤーの指定（select）に当たるものを選ぶ
    const selectNodes = (nodes, layerSpec) => nodes.filter((node) => layerSpec.select === 'all'
        || (layerSpec.select === 'text' && node.isTextNode)
        || (layerSpec.select === 'nontext' && !node.isTextNode)) ;
    // 文字全体を範囲選択した選択（setText・formatText で全文を対象にするため。開発時の試行 C4）
    function storySelection(node) {
        const selection = Selection.create(doc, node) ;
        selection.addSubSelectionForNode(node, TextSelection.create(node.storyRange)) ;
        return selection ;
    }
    // 外枠の基準の点：横は揃えに応じて左端・中央・右端、縦は中央。
    // 文字の外枠は base box（字形の外形）を使う。visible box は右に約 0.7 mm 広く、中央が文字の中央からずれるため
    function anchorPoint(node, align) {
        const box = node.getSpreadBaseBox() ;
        const x = { left: box.x, center: box.x + box.width/2, right: box.x + box.width }[align] ;
        return { x, y: box.y + box.height/2 } ;
    }
    // 揃えを設定し、字間を 0 に戻し、基準の点を target（省略時は元の位置）へ合わせる。戻した量と残差 [px] を返す
    function setAlignment(node, align, target) {
        const anchor = target ?? anchorPoint(node, align) ;
        doc.formatText(StoryDelta.createGlyphDouble(GlyphAttDoubleType.CharacterSpacing, 0), storySelection(node)) ;
        doc.formatText(StoryDelta.createAlignX(alignTypes[align]), storySelection(node)) ;
        const moved = anchorPoint(node, align) ;
        doc.executeCommand(DocumentCommand.createTransform(Selection.create(doc, node), Transform.createTranslate(anchor.x - moved.x, anchor.y - moved.y))) ;
        const placed = anchorPoint(node, align) ;
        return { correction: Math.hypot(anchor.x - moved.x, anchor.y - moved.y), residual: Math.hypot(anchor.x - placed.x, anchor.y - placed.y) } ;
    }
    // 取り込み時に 1 つにまとまった横軸の目盛り：連続する目盛りの文字を空白でつないだものと一致すれば、その範囲を返す
    const xTickLabels = spec.ticks.x.labels ;
    function mergedTickRange(text) {
        for (let start = 0 ; start < xTickLabels.length ; start += 1) {
            for (let end = start + 2 ; end <= xTickLabels.length ; end += 1) {
                if (xTickLabels.slice(start, end).join(' ') === text) {
                    return { start, end } ;
                }
            }
        }
        return null ;
    }

    const alignmentCounts = { left: 0, center: 0, right: 0 } ;
    let maxCorrection = 0 ;
    let maxResidual = 0 ;
    let splitCount = 0 ;
    const record = (align, result) => {
        alignmentCounts[align] += 1 ;
        maxCorrection = Math.max(maxCorrection, result.correction) ;
        maxResidual = Math.max(maxResidual, result.residual) ;
    } ;
    for (const page of spec.pages) {
        doc.executeCommand(DocumentCommand.createSetCurrentSpread(spreadOfPage(page.page - 1))) ;
        const nodes = pageParents[page.page - 1].children.toArray() ;
        const verticalLines = nodes.filter((node) => !node.isTextNode)
            .map((node) => node.getSpreadVisibleBox())
            .filter((box) => box.height > 5*box.width) ; // イベント線などの縦線
        for (const layerSpec of page.layers) {
            for (const node of selectNodes(nodes, layerSpec).filter((item) => item.isTextNode)) {
                // 横軸のページで 1 つにまとまった目盛りは、目盛りごとに複製して文字を置き換え、目盛りの位置に置く
                const merged = page.component === 'x axis' ? mergedTickRange(node.text.trim()) : null ;
                if (merged) {
                    const box = node.getSpreadBaseBox() ;
                    const centreY = box.y + box.height/2 ;
                    const originalAtts = node.story.getGlyphAtts(0) ;
                    const sizePt = textSizePt(node) ;
                    for (let index = merged.start ; index < merged.end ; index += 1) {
                        const copy = node.duplicate(Transform.createTranslate(0, 0)) ;
                        doc.setText(xTickLabels[index], storySelection(copy)) ;
                        // 置き換えた文字の属性を元に戻す（高さは換算した値で上書きする：開発時の試行 C4）
                        doc.formatText(StoryDelta.createComposite([
                            StoryDelta.createFromGlyphAtts(originalAtts),
                            StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, sizePt*pxPerPt),
                        ]), storySelection(copy)) ;
                        const tickX = toPage(spec.ticks.x.values[index], spec.ylim[0]).x ;
                        record(layerSpec.align, setAlignment(copy, layerSpec.align, { x: tickX, y: centreY })) ;
                    }
                    doc.deleteSelection(Selection.create(doc, node)) ;
                    splitCount += 1 ;
                    continue ;
                }
                // 揃え：JSON の指定（MATLAB が成分ごとに決める）。指定がなければ、縦線の名前は線の側（線の右なら左揃え）、その他は中央
                let align = layerSpec.align ;
                if (!align) {
                    align = 'center' ;
                    if (verticalLines.length > 0) {
                        const box = node.getSpreadBaseBox() ;
                        const centreX = box.x + box.width/2 ;
                        const nearest = verticalLines.reduce((best, line) =>
                            (Math.abs(line.x + line.width/2 - centreX) < Math.abs(best.x + best.width/2 - centreX) ? line : best)) ;
                        align = centreX > nearest.x + nearest.width/2 ? 'left' : 'right' ;
                    }
                }
                record(align, setAlignment(node, align)) ;
            }
        }
    }
    console.log(`[text align] left=${alignmentCounts.left}, center=${alignmentCounts.center}, right=${alignmentCounts.right}; `
        + `merged tick labels split=${splitCount}; max correction=${(maxCorrection/pxPerMm).toFixed(3)} mm, max residual=${(maxResidual/pxPerMm).toFixed(4)} mm`) ;

    // ---- 5. レイヤー構成：背面から Figure area、Notes（非表示、reference）、Panel A の順に作り、ページの要素をサブレイヤーへ移す ----
    // Figure area：図全体の領域（段の幅 × 図の高さ、JSON の figureArea）を示す矩形。塗り・線なしで、誤って動かさないようロックする。
    // 書き出しの範囲はページなので、8 の段階でページの大きさもこの矩形に合わせる。
    // 名前の設定は現在の見開きの要素にしかできない（COMMAND_FAILED になる）ので、先に 1 ページ目を現在の見開きにする
    doc.executeCommand(DocumentCommand.createSetCurrentSpread(firstSpread)) ;
    const pageOrigin = firstSpread.getSpreadBaseBox() ;
    const areaWidth = spec.figureArea.widthMm*pxPerMm ;
    const areaHeight = spec.figureArea.heightMm*pxPerMm ;
    const areaLayer = addLayer(firstSpread, 'Figure area') ;
    const areaBuilder = AddChildNodesCommandBuilder.create() ;
    areaBuilder.setInsertionTarget(areaLayer) ;
    areaBuilder.addNode(ShapeNodeDefinition.create(ShapeRectangle.create(), new Rectangle(pageOrigin.x, pageOrigin.y, areaWidth, areaHeight),
        FillDescriptor.createNone(), FillDescriptor.createNone(), LineStyleDescriptor.create(LineStyle.createDefaultWithWeight(0), {}), FillDescriptor.createNone())) ;
    const areaRect = executeAndGetNode(areaBuilder) ;
    areaRect.userDescription = `figure area (${spec.figureArea.column} column, ${spec.figureArea.widthMm} x ${spec.figureArea.heightMm} mm)` ;
    doc.setEditable(false, Selection.create(doc, areaRect)) ;
    // 同じ名前のサブレイヤー（横軸と縦軸のページの axes lines・tick labels）は、最初に作ったものへまとめる
    const notesLayer = addLayer(firstSpread, 'Notes') ;
    const referenceLayer = addLayer(notesLayer, 'reference (MATLAB full figure)') ;
    moveInto(pageNodes[0], firstSpread, referenceLayer) ;
    const panelLayer = addLayer(firstSpread, `Panel ${spec.panel}`) ;
    const findSubLayer = (name) => panelLayer.children.toArray().find((layer) => layer.userDescription === name) ;
    for (const page of spec.pages) {
        const nodes = pageParents[page.page - 1].children.toArray() ; // 揃えの段階で目盛りを分けたので、読み直す
        for (const layerSpec of page.layers) {
            const subLayer = findSubLayer(layerSpec.name) ?? addLayer(panelLayer, layerSpec.name) ;
            moveInto(selectNodes(nodes, layerSpec), spreadOfPage(page.page - 1), subLayer) ;
        }
    }
    doc.executeCommand(DocumentCommand.createSetCurrentSpread(firstSpread)) ;
    doc.setVisible(false, Selection.create(doc, notesLayer)) ;
    console.log(`[layers] Panel ${spec.panel}: ${panelLayer.children.toArray().map((layer) => `${layer.userDescription}(${layer.children.toArray().length})`).join(', ')}`) ;

    // ---- 6. 位置合わせ用の点と一時的なレイヤーを削除する（複数ページの PDF から組み立てたときは、空のページが残る）----
    doc.executeCommand(DocumentCommand.createSetCurrentSpread(spreadOfPage(spec.calibration.page - 1))) ;
    doc.deleteSelection(Selection.create(doc, calibrationNodes)) ;
    doc.executeCommand(DocumentCommand.createSetCurrentSpread(firstSpread)) ;
    removeTemporaryLayers(temporaryLayers) ;
    const nonEmptyPages = doc.spreads.toArray().filter((spread) => spread.children.toArray().length > 0).length ;
    console.log(`[pages] pages=${doc.spreads.toArray().length}, pages with content=${nonEmptyPages}`) ;

    // 確認：横軸の目盛りの文字の中央と、位置合わせから求めた目盛りの位置の差（分けた文字と MATLAB が置いた文字が揃っているか）
    const tickLabelLayer = findSubLayer(`${spec.panel}: tick labels`) ;
    const tickOffsets = [] ;
    for (const node of tickLabelLayer.children.toArray().filter((item) => item.isTextNode)) {
        const index = xTickLabels.indexOf(node.text.trim()) ;
        const box = node.getSpreadBaseBox() ;
        if (index >= 0 && box.y > axisOrigin.y) {
            tickOffsets.push(`${node.text.trim()}:${((box.x + box.width/2 - toPage(spec.ticks.x.values[index], spec.ylim[0]).x)/pxPerMm).toFixed(2)}`) ;
        }
    }
    console.log(`[text align] x tick label centre - tick position [mm]: ${tickOffsets.join(' ')}`) ;

    // ---- 7. 注釈：A: annotations（パネルのサブレイヤーの最前面）----
    // 注釈の文字の大きさ：目盛りの文字で最も多い大きさに合わせる。
    // 軸ラベルは目盛りより大きい（createPanelAxes の LabelFontSizeMultiplier で 9/7.5 = 1.2 倍）ので、軸ラベルには合わせない
    const sizeCounts = new Map() ;
    for (const node of tickLabelLayer.children.toArray().filter((item) => item.isTextNode)) {
        const size = Number(textSizePt(node).toFixed(2)) ;
        sizeCounts.set(size, (sizeCounts.get(size) ?? 0) + 1) ;
    }
    const annotationTextPt = [...sizeCounts.entries()].sort((a, b) => b[1] - a[1])[0][0] ;
    const annotationWeightPt = spec.lineWidthPt ;
    const annotationLayer = addLayer(panelLayer, `${spec.panel}: annotations`) ;

    // 折れ線（矢じりは任意）を追加する。points は [px]
    function addPolyline(points, arrows) {
        const builder = CurveBuilder.create().begin(points[0]) ;
        for (const point of points.slice(1)) {
            builder.lineTo(point) ;
        }
        const polyCurve = PolyCurve.create() ;
        polyCurve.addCurve(builder.createCurve()) ;
        const lineStyle = LineStyle.createDefaultWithWeight(annotationWeightPt*pxPerPt) ;
        const descriptor = LineStyleDescriptor.create(lineStyle, arrows ?? {}) ;
        // 第 5 引数（透明度の塗り）は省略できない（開発時の試行 7.4 節）ので、塗りなしを渡す
        const definition = PolyCurveNodeDefinition.create(polyCurve, FillDescriptor.createNone(), FillDescriptor.createSolid(black), descriptor, FillDescriptor.createNone()) ;
        const builderNode = AddChildNodesCommandBuilder.create() ;
        builderNode.setInsertionTarget(annotationLayer) ;
        builderNode.addNode(definition) ;
        return executeAndGetNode(builderNode) ;
    }
    // Arial の文字を置く。anchor は「横-縦」（left/center/right と top/middle/bottom）で、外枠のその点を (x, y) [px] に合わせる。
    // 揃えは anchor の横の基準と同じにする（左端で置く文字は左揃え、中央で置く文字は中央揃え、右端で置く文字は右揃え）
    function addText(text, x, y, anchor) {
        const [horizontal, vertical] = anchor.split('-') ;
        const storyBuilder = StoryBuilder.create() ;
        storyBuilder.setToArtisticTextDefaultStyle(doc.dpi, doc.rasterFormat) ;
        storyBuilder.applyGlyphDelta(StoryDelta.createComposite([
            StoryDelta.createFamilyName('Arial'),
            StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, annotationTextPt*pxPerPt),
        ])) ;
        storyBuilder.applyParagraphDelta(StoryDelta.createAlignX(alignTypes[horizontal])) ;
        storyBuilder.addText(text) ;
        const builder = AddChildNodesCommandBuilder.create() ;
        builder.setInsertionTarget(annotationLayer) ;
        builder.addNode(ArtTextNodeDefinition.createFromStoryBuilder(new Point(x, y), storyBuilder)) ;
        const node = executeAndGetNode(builder) ;
        const box = node.getSpreadBaseBox() ; // 文字送りの幅の外枠（anchorPoint と同じ理由で visible box は使わない）
        const anchorX = { left: box.x, center: box.x + box.width/2, right: box.x + box.width }[horizontal] ;
        const anchorY = { top: box.y, middle: box.y + box.height/2, bottom: box.y + box.height }[vertical] ;
        doc.executeCommand(DocumentCommand.createTransform(Selection.create(doc, node), Transform.createTranslate(x - anchorX, y - anchorY))) ;
        return node ;
    }
    const arrowHead = () => ArrowHead.create(ArrowHeadStyle.Triangle, { scaleX: 1, scaleY: 1 }) ;

    for (const annotation of spec.annotations ?? []) {
        let nodes = [] ;
        if (annotation.type === 'text') {
            const position = toPage(...annotation.position) ;
            const [dxMm, dyMm] = annotation.offsetMm ?? [0, 0] ;
            nodes = [addText(annotation.text, position.x + dxMm*pxPerMm, position.y - dyMm*pxPerMm, annotation.anchor)] ;
        } else if (annotation.type === 'arrow') {
            // 矢じりの先端（to）は gapMm だけ手前で止める
            const tail = toPage(...annotation.from) ;
            const target = toPage(...annotation.to) ;
            const length = Math.hypot(target.x - tail.x, target.y - tail.y) ;
            const gap = (annotation.gapMm ?? 0)*pxPerMm ;
            const tip = new Point(target.x - (target.x - tail.x)/length*gap, target.y - (target.y - tail.y)/length*gap) ;
            const arrows = annotation.heads === 'both' ? { frontArrow: arrowHead(), backArrow: arrowHead() } : { backArrow: arrowHead() } ;
            nodes = [addPolyline([tail, tip], arrows)] ;
        } else if (annotation.type === 'bracket') {
            // 有意差のブラケット（両端を legMm だけ下げる）と記号（ブラケットの上 textGapMm）
            const left = toPage(annotation.x[0], annotation.y) ;
            const right = toPage(annotation.x[1], annotation.y) ;
            const leg = annotation.legMm*pxPerMm ;
            const bracket = addPolyline([new Point(left.x, left.y + leg), left, right, new Point(right.x, right.y + leg)]) ;
            const symbol = addText(annotation.text, (left.x + right.x)/2, left.y - annotation.textGapMm*pxPerMm, 'center-bottom') ;
            nodes = [bracket, symbol] ;
        } else {
            console.log(`[annotation] unknown type ${annotation.type}`) ;
            continue ;
        }
        nodes.forEach((node, index) => {
            node.userDescription = nodes.length === 1 ? annotation.name : `${annotation.name} ${index === 0 ? 'bracket' : 'symbol'}` ;
        }) ;
    }
    console.log(`[annotations] ${annotationLayer.children.toArray().map((node) => node.userDescription).join(', ')} (text ${annotationTextPt.toFixed(2)} pt, line ${annotationWeightPt} pt)`) ;

    // ---- 8. 文字と線幅の集計（パネル内のすべて）----
    const allPanelNodes = collectNodes(panelLayer, []) ;
    const fontSummary = new Set() ;
    for (const node of allPanelNodes.filter((item) => item.isTextNode)) {
        for (const run of node.story.getGlyphAttRunsFrom(0).toArray()) {
            fontSummary.add(`${run.glyphAtts.font.familyName} ${(run.glyphAtts.height*transformScale(node.baseToSpreadTransform)*72/doc.dpi).toFixed(2)}pt`) ;
        }
    }
    const lineWeights = new Set(allPanelNodes
        .filter((node) => node.isVectorNode && node.hasPenFill && node.lineWeight > 0)
        .map((node) => (node.lineWeight*transformScale(node.localToSpreadTransform)*72/doc.dpi).toFixed(2))) ;
    console.log(`[check] text: ${[...fontSummary].join(', ')}; line weights [pt]: ${[...lineWeights].sort().join(', ')}`) ;

    // ---- 8. ページ（書き出しの範囲）を図全体の領域の矩形に合わせる（左上を基準にするので、要素は動かない）----
    doc.setSpreadSizeWithAnchor(firstSpread, areaWidth, areaHeight, SpatialAnchor.TopLeft) ;
    const pageBox = firstSpread.getSpreadBaseBox() ;
    const rectBox = areaRect.getSpreadBaseBox() ;
    const panelBox = panelLayer.getSpreadVisibleBox() ;
    console.log(`[figure area] page ${(pageBox.width/pxPerMm).toFixed(2)} x ${(pageBox.height/pxPerMm).toFixed(2)} mm at (${(pageBox.x/pxPerMm).toFixed(2)}, ${(pageBox.y/pxPerMm).toFixed(2)}), `
        + `rect ${(rectBox.width/pxPerMm).toFixed(2)} x ${(rectBox.height/pxPerMm).toFixed(2)} mm at (${(rectBox.x/pxPerMm).toFixed(2)}, ${(rectBox.y/pxPerMm).toFixed(2)}), `
        + `panel content x ${(panelBox.x/pxPerMm).toFixed(2)}-${((panelBox.x + panelBox.width)/pxPerMm).toFixed(2)} mm, y ${(panelBox.y/pxPerMm).toFixed(2)}-${((panelBox.y + panelBox.height)/pxPerMm).toFixed(2)} mm`) ;

    // ---- 8. 保存と書き出し ----
    try {
        doc.saveAs(joinPath(savedDir, `${spec.name}.af`)) ;
        console.log(`[save] ${joinPath(savedDir, `${spec.name}.af`)}`) ;
    } catch (error) {
        console.log(`[save] exception ${error.message}`) ;
    }
    const firstPage = FileExportArea.createForPages('1') ;
    for (const [fileName, presetName] of [[`${spec.name}.pdf`, pdfExportPresetName], [`${spec.name}.png`, 'PNG']]) {
        const records = doc.export(joinPath(exportDir, fileName), FileExportOptions.createWithPresetName(presetName), firstPage) ;
        for (const record of records.all) {
            console.log(`[export] ${fileName}: ${record.isSuccess ? 'OK' : `NG ${record.errorMessage}`}${record.hasWarnings ? ` warning: ${record.warningMessage}` : ''}`) ;
        }
    }
    // 複数ページの文書でページ範囲を指定したラスターの書き出しは、ファイル名に _1 が付く（開発時の試行 G7）ので付け直す
    try {
        fs.rename(joinPath(exportDir, `${spec.name}_1.png`), joinPath(exportDir, `${spec.name}.png`)) ;
    } catch (error) {
        // 1 ページの文書（1 ページに並べた PDF から組み立てたもの）では _1 が付かないので、ファイルがないのは正常
        if (!/NO_SUCH_FILE/.test(error.message)) {
            console.log(`[export] rename png: ${error.message}`) ;
        }
    }

    // 書き出した PDF を開き直し、非表示の Notes が含まれていないか（文字の数がパネルと同じか）を確かめる
    const panelTextCount = allPanelNodes.filter((node) => node.isTextNode).length ;
    const panelVectorCount = allPanelNodes.filter((node) => node.isVectorNode).length ;
    const exportedDoc = Document.load(joinPath(exportDir, `${spec.name}.pdf`)) ;
    const exportedNodes = collectNodes(exportedDoc.spreads.toArray()[0], []) ;
    const exportedBox = exportedDoc.spreads.toArray()[0].getSpreadBaseBox() ;
    console.log(`[verify] exported PDF: ${(exportedBox.width/(exportedDoc.dpi/25.4)).toFixed(1)} x ${(exportedBox.height/(exportedDoc.dpi/25.4)).toFixed(1)} mm, `
        + `text ${exportedNodes.filter((node) => node.isTextNode).length} (panel ${panelTextCount}), `
        + `vector ${exportedNodes.filter((node) => node.isVectorNode).length} (panel ${panelVectorCount})`) ;
    exportedDoc.close() ;
    return doc ;
}


// ---------------------------------------------------------------
// 実行
// ---------------------------------------------------------------

const specs = readSpecs() ;
console.log(`specs: ${specs.map((spec) => spec.name).join(', ')}`) ;
for (const spec of specs) {
    try {
        composePanel(spec) ;
    } catch (error) {
        console.log(`[${spec.name}] exception ${error.message}\n${error.stack}`) ;
    }
}
console.log(`open documents: ${app.documents.all.map((openDoc) => `${openDoc.title}=${openDoc.sessionUuid}`).join(', ')}`) ;
