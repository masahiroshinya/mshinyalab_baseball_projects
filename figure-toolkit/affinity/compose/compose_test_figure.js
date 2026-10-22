// 複数パネルの試験用の図の組み立て（スクリプトパネル「Panel style」の試験用。2026-10-19）
//
// 入力：デスクトップの affinity_mcp_work/input/test_figures/test_figure_4panels.json と _components.pdf
//       （tools/make_test_figure_4panels.py が、単一パネルの 4 図の成分のページを 1 つの PDF にまとめて作る。
//        続けて tools/stack_component_pages.py で 1 ページに並べると、.af に空のページが残らない：compose_single_panels.js の手順 1）
// 処理：compose_single_panels.js（単一パネル）と同じ手順（位置合わせ用の点からの座標の対応、文字の揃え、サブレイヤーへの振り分け、注釈）を
//       パネルごとに行い、Panel X と比較用の全体図を JSON の offsetMm の位置へ平行移動する。
//       図全体のレイヤーは前面から Labels（パネル記号）、Panel A〜D、Notes（非表示、比較用の全体図）、Figure area（docs/figure-assembly-style.md の 1 節）。
//       ページの大きさを Figure area に合わせ、.af の保存と PDF・PNG の書き出しを行う。
// 試験用：複数パネルの組み立ての方針（幅の割り振り、余白の揃え方）は未決定。決まったら compose_single_panels.js と統合する。
//         compose_single_panels.js との違いは、1 つの PDF に複数パネルのページがあること、パネルを平行移動すること、Labels を作ること。
// 実行（figure-toolkit のフォルダで）：AFFINITY_COLLECT_DIR=<移す先の絶対パス> node tools/affinity-mcp.mjs run affinity/compose/compose_test_figure.js
//       引数（--set）：testFigureName=<図の名前>（既定 test_figure_4panels）、inputFolder=<フォルダ名>（既定 test_figures）

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
const { FontWeight } = require('/fonts') ;
const { Colour } = require('/colours') ;
const { File, fs } = require('/fs') ;
// PDF の書き出しのプリセット「書き出し用」の名前（Affinity の表示の言語で変わるので、日本語と英語の名前、なければ名前の形で探す）
const pdfExportPresetName = ['PDF(書き出し用)', 'PDF (for export)'].find((name) => FileExportOptions.allPresetNames.includes(name))
    ?? FileExportOptions.allPresetNames.find((name) => /^PDF.*(書き出し|export)/i.test(name)) ;

// パスの区切り：Windows は \、Mac は /（デスクトップの場所の書き方から判断する）
const pathSeparator = app.userDesktopPath.includes('\\') ? '\\' : '/' ;
const joinPath = (...parts) => parts.join(pathSeparator) ;
const workDir = joinPath(app.userDesktopPath, 'affinity_mcp_work') ;
const inputDir = joinPath(workDir, 'input', globalThis.inputFolder ?? 'test_figures') ; // 引数（--set）：inputFolder=<フォルダ名>
const exportDir = joinPath(workDir, 'export') ;
const savedDir = joinPath(workDir, 'panels') ;
const figureName = globalThis.testFigureName ?? 'test_figure_4panels' ; // 引数（--set）：testFigureName=<図の名前>
const defaultPanelLabelSizePt = 9.75 ; // パネル記号の文字サイズ [pt]（Arial Bold）。JSON に fontSizePt.panelLabel がないときに使う（docs/figure-panel-style.md の 2 節）
const panelLabelInsetMm = [1, 1] ; // パネル記号の左上の、パネルの左上からの位置 [mm]
const black = Colour.createRGBA8({ r: 0, g: 0, b: 0, alpha: 255 }) ;
const alignTypes = { left: ParagraphAlignXType.Left, center: ParagraphAlignXType.Centre, right: ParagraphAlignXType.Right } ;


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


// ---------------------------------------------------------------
// 図の組み立て
// ---------------------------------------------------------------

function composeFigure(figure) {
    // 前回の実行で開いた同じ図のドキュメントは閉じる。保存していない変更があれば止める
    for (const openDoc of app.documents.all) {
        if (openDoc.title === figure.componentsPdf || openDoc.title === figure.stackedPdf || openDoc.title === figure.name) {
            // 保存していない変更がある文書は閉じない（ユーザーが Affinity で手を加えた可能性がある。変更が失われないように止める）
            // 同じ名前で保存してもらうと、下の saveAs が affinity_mcp_work/panels/<名前>.af を上書きするので、別の名前で保存してもらう
            if (openDoc.isDirty) {
                throw new Error(`「${openDoc.title}」に保存していない変更があるため、閉じずに止めた。変更を残す場合は、Affinity で別の名前で保存して閉じる`
                    + `（同じ名前で保存すると、組み立て直したときに affinity_mcp_work/panels/${figure.name}.af が上書きされる）。`
                    + `残さない場合は、変更を破棄して閉じる。その後、もう一度実行する`) ;
            }
            openDoc.close() ;
        }
    }
    const doc = Document.load(joinPath(inputDir, figure.stackedPdf ?? figure.componentsPdf)) ;
    const pxPerMm = doc.dpi/25.4 ;
    const pxPerPt = doc.dpi/72 ;
    const spreads = doc.spreads.toArray() ;
    const firstSpread = spreads[0] ;
    console.log(`== ${figure.name}: uuid=${doc.sessionUuid}, pages=${spreads.length}, panels=${figure.panels.map((p) => p.panel).join(',')}`) ;

    // ---- 文書の操作 ----
    const setCurrent = (spread) => doc.executeCommand(DocumentCommand.createSetCurrentSpread(spread)) ;
    function executeAndGetNode(builder) {
        const command = builder.createCommand(false, NodeChildType.Main) ;
        doc.executeCommand(command) ;
        return command.newNodes[0] ;
    }
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
        setCurrent(sourceSpread) ;
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
    const { pageParents, spreadOfPage, temporaryLayers } = openComponentPages(figure.stackedPages) ;
    const pageNodes = pageParents.map((parent) => parent.children.toArray()) ; // 開いたときの各ページの要素
    function storySelection(node) {
        const selection = Selection.create(doc, node) ;
        selection.addSubSelectionForNode(node, TextSelection.create(node.storyRange)) ;
        return selection ;
    }
    const textSizePt = (node) => node.story.getGlyphAtts(0).height*transformScale(node.baseToSpreadTransform)*72/doc.dpi ;
    // 外枠の基準の点（文字は base box を使う：compose_single_panels.js と同じ）
    function anchorPoint(node, align) {
        const box = node.getSpreadBaseBox() ;
        const x = { left: box.x, center: box.x + box.width/2, right: box.x + box.width }[align] ;
        return { x, y: box.y + box.height/2 } ;
    }
    // 揃えを設定し、字間を 0 に戻し、基準の点を target（省略時は元の位置）へ合わせる
    function setAlignment(node, align, target) {
        const anchor = target ?? anchorPoint(node, align) ;
        doc.formatText(StoryDelta.createGlyphDouble(GlyphAttDoubleType.CharacterSpacing, 0), storySelection(node)) ;
        doc.formatText(StoryDelta.createAlignX(alignTypes[align]), storySelection(node)) ;
        const moved = anchorPoint(node, align) ;
        doc.executeCommand(DocumentCommand.createTransform(Selection.create(doc, node), Transform.createTranslate(anchor.x - moved.x, anchor.y - moved.y))) ;
    }
    // 文字を置く（Arial、揃えは anchor の横の基準と同じ）。anchor は「横-縦」で、base box のその点を (x, y) に合わせる
    function addText(layer, text, sizePt, x, y, anchor, bold) {
        const [horizontal, vertical] = anchor.split('-') ;
        const storyBuilder = StoryBuilder.create() ;
        storyBuilder.setToArtisticTextDefaultStyle(doc.dpi, doc.rasterFormat) ;
        const deltas = [StoryDelta.createFamilyName('Arial'), StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, sizePt*pxPerPt)] ;
        if (bold) {
            deltas.push(StoryDelta.createWeight(FontWeight.Bold)) ;
        }
        storyBuilder.applyGlyphDelta(StoryDelta.createComposite(deltas)) ;
        storyBuilder.applyParagraphDelta(StoryDelta.createAlignX(alignTypes[horizontal])) ;
        storyBuilder.addText(text) ;
        const builder = AddChildNodesCommandBuilder.create() ;
        builder.setInsertionTarget(layer) ;
        builder.addNode(ArtTextNodeDefinition.createFromStoryBuilder(new Point(x, y), storyBuilder)) ;
        const node = executeAndGetNode(builder) ;
        const box = node.getSpreadBaseBox() ;
        const anchorX = { left: box.x, center: box.x + box.width/2, right: box.x + box.width }[horizontal] ;
        const anchorY = { top: box.y, middle: box.y + box.height/2, bottom: box.y + box.height }[vertical] ;
        doc.executeCommand(DocumentCommand.createTransform(Selection.create(doc, node), Transform.createTranslate(x - anchorX, y - anchorY))) ;
        return node ;
    }
    function addPolyline(layer, points, weightPt, arrows) {
        const builder = CurveBuilder.create().begin(points[0]) ;
        for (const point of points.slice(1)) {
            builder.lineTo(point) ;
        }
        const polyCurve = PolyCurve.create() ;
        polyCurve.addCurve(builder.createCurve()) ;
        const descriptor = LineStyleDescriptor.create(LineStyle.createDefaultWithWeight(weightPt*pxPerPt), arrows ?? {}) ;
        const definition = PolyCurveNodeDefinition.create(polyCurve, FillDescriptor.createNone(), FillDescriptor.createSolid(black), descriptor, FillDescriptor.createNone()) ;
        const addBuilder = AddChildNodesCommandBuilder.create() ;
        addBuilder.setInsertionTarget(layer) ;
        addBuilder.addNode(definition) ;
        return executeAndGetNode(addBuilder) ;
    }
    const arrowHead = () => ArrowHead.create(ArrowHeadStyle.Triangle, { scaleX: 1, scaleY: 1 }) ;

    // ---- 図全体の土台：Figure area（最背面）と Notes（非表示）----
    setCurrent(firstSpread) ;
    const pageOrigin = firstSpread.getSpreadBaseBox() ;
    const areaWidth = figure.figureArea.widthMm*pxPerMm ;
    const areaHeight = figure.figureArea.heightMm*pxPerMm ;
    const areaLayer = addLayer(firstSpread, 'Figure area') ;
    const areaBuilder = AddChildNodesCommandBuilder.create() ;
    areaBuilder.setInsertionTarget(areaLayer) ;
    areaBuilder.addNode(ShapeNodeDefinition.create(ShapeRectangle.create(), new Rectangle(pageOrigin.x, pageOrigin.y, areaWidth, areaHeight),
        FillDescriptor.createNone(), FillDescriptor.createNone(), LineStyleDescriptor.create(LineStyle.createDefaultWithWeight(0), {}), FillDescriptor.createNone())) ;
    const areaRect = executeAndGetNode(areaBuilder) ;
    areaRect.userDescription = `figure area (${figure.figureArea.column} column, ${figure.figureArea.widthMm} x ${figure.figureArea.heightMm} mm)` ;
    doc.setEditable(false, Selection.create(doc, areaRect)) ;
    const notesLayer = addLayer(firstSpread, 'Notes') ;

    // ---- パネルごとの組み立て ----
    const panelLayers = [] ;
    for (const spec of figure.panels) {
        const panel = spec.panel ;

        // データ座標 → ページ上の位置 [px]（位置合わせ用の点 2 つから）
        const calibrationNodes = pageNodes[spec.calibration.page - 1] ;
        if (calibrationNodes.length !== 2) {
            throw new Error(`${panel}: 位置合わせ用のページの要素が ${calibrationNodes.length} 個（2 個のはず）`) ;
        }
        const measured = calibrationNodes.map(boxCentre).sort((a, b) => a.x - b.x) ;
        const [dataLow, dataHigh] = spec.calibration.points ;
        const xScale = (measured[1].x - measured[0].x)/(dataHigh[0] - dataLow[0]) ;
        const yScale = (measured[1].y - measured[0].y)/(dataHigh[1] - dataLow[1]) ;
        const toPage = (x, y) => new Point(measured[0].x + xScale*(x - dataLow[0]), measured[0].y + yScale*(y - dataLow[1])) ;

        // 文字の揃え（サブレイヤーへ移す前に、ページごとに行う。まとまった横軸の目盛りは分ける）
        const xTickLabels = spec.ticks.x.labels ;
        const mergedTickRange = (text) => {
            for (let start = 0 ; start < xTickLabels.length ; start += 1) {
                for (let end = start + 2 ; end <= xTickLabels.length ; end += 1) {
                    if (xTickLabels.slice(start, end).join(' ') === text) {
                        return { start, end } ;
                    }
                }
            }
            return null ;
        } ;
        const selectNodes = (nodes, layerSpec) => nodes.filter((node) => layerSpec.select === 'all'
            || (layerSpec.select === 'text' && node.isTextNode)
            || (layerSpec.select === 'nontext' && !node.isTextNode)) ;
        let splitCount = 0 ;
        for (const page of spec.pages) {
            setCurrent(spreadOfPage(page.page - 1)) ;
            const nodes = pageParents[page.page - 1].children.toArray() ;
            const verticalLines = nodes.filter((node) => !node.isTextNode)
                .map((node) => node.getSpreadVisibleBox())
                .filter((box) => box.height > 5*box.width) ;
            for (const layerSpec of page.layers) {
                for (const node of selectNodes(nodes, layerSpec).filter((item) => item.isTextNode)) {
                    const merged = page.component === 'x axis' ? mergedTickRange(node.text.trim()) : null ;
                    if (merged) {
                        const box = node.getSpreadBaseBox() ;
                        const centreY = box.y + box.height/2 ;
                        const originalAtts = node.story.getGlyphAtts(0) ;
                        const sizePt = textSizePt(node) ;
                        for (let index = merged.start ; index < merged.end ; index += 1) {
                            const copy = node.duplicate(Transform.createTranslate(0, 0)) ;
                            doc.setText(xTickLabels[index], storySelection(copy)) ;
                            doc.formatText(StoryDelta.createComposite([
                                StoryDelta.createFromGlyphAtts(originalAtts),
                                StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, sizePt*pxPerPt),
                            ]), storySelection(copy)) ;
                            setAlignment(copy, layerSpec.align, { x: toPage(spec.ticks.x.values[index], spec.ylim[0]).x, y: centreY }) ;
                        }
                        doc.deleteSelection(Selection.create(doc, node)) ;
                        splitCount += 1 ;
                        continue ;
                    }
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
                    setAlignment(node, align) ;
                }
            }
        }

        // レイヤー：比較用の全体図は Notes の中へ、成分は Panel X のサブレイヤーへ（同じ名前のサブレイヤーは 1 つにまとめる）
        setCurrent(firstSpread) ;
        const referenceLayer = addLayer(notesLayer, `reference ${panel} (MATLAB full figure)`) ;
        // 開いたときに集めた要素を使う（A の比較用のページは 1 ページ目で、後から加えた Figure area・Notes が同じページにあるため）
        moveInto(pageNodes[spec.referencePage - 1], spreadOfPage(spec.referencePage - 1), referenceLayer) ;
        setCurrent(firstSpread) ;
        const panelLayer = addLayer(firstSpread, `Panel ${panel}`) ;
        const findSubLayer = (name) => panelLayer.children.toArray().find((layer) => layer.userDescription === name) ;
        for (const page of spec.pages) {
            const nodes = pageParents[page.page - 1].children.toArray() ;
            for (const layerSpec of page.layers) {
                setCurrent(firstSpread) ;
                const subLayer = findSubLayer(layerSpec.name) ?? addLayer(panelLayer, layerSpec.name) ;
                moveInto(selectNodes(nodes, layerSpec), spreadOfPage(page.page - 1), subLayer) ;
            }
        }
        // 位置合わせ用の点を削除する（複数ページの PDF から組み立てたときは、ページは SDK では削除できないので、空のページが残る）
        setCurrent(spreadOfPage(spec.calibration.page - 1)) ;
        doc.deleteSelection(Selection.create(doc, calibrationNodes)) ;
        setCurrent(firstSpread) ;

        // 注釈：X: annotations（文字の大きさは目盛りの文字で最も多い大きさ）
        const tickLabelLayer = findSubLayer(`${panel}: tick labels`) ;
        const sizeCounts = new Map() ;
        for (const node of tickLabelLayer.children.toArray().filter((item) => item.isTextNode)) {
            const size = Number(textSizePt(node).toFixed(2)) ;
            sizeCounts.set(size, (sizeCounts.get(size) ?? 0) + 1) ;
        }
        const annotationTextPt = [...sizeCounts.entries()].sort((a, b) => b[1] - a[1])[0][0] ;
        const annotationLayer = addLayer(panelLayer, `${panel}: annotations`) ;
        for (const annotation of spec.annotations ?? []) {
            let nodes = [] ;
            if (annotation.type === 'text') {
                const position = toPage(...annotation.position) ;
                const [dxMm, dyMm] = annotation.offsetMm ?? [0, 0] ;
                nodes = [addText(annotationLayer, annotation.text, annotationTextPt, position.x + dxMm*pxPerMm, position.y - dyMm*pxPerMm, annotation.anchor, false)] ;
            } else if (annotation.type === 'arrow') {
                const tail = toPage(...annotation.from) ;
                const target = toPage(...annotation.to) ;
                const length = Math.hypot(target.x - tail.x, target.y - tail.y) ;
                const gap = (annotation.gapMm ?? 0)*pxPerMm ;
                const tip = new Point(target.x - (target.x - tail.x)/length*gap, target.y - (target.y - tail.y)/length*gap) ;
                const arrows = annotation.heads === 'both' ? { frontArrow: arrowHead(), backArrow: arrowHead() } : { backArrow: arrowHead() } ;
                nodes = [addPolyline(annotationLayer, [tail, tip], spec.lineWidthPt, arrows)] ;
            } else if (annotation.type === 'bracket') {
                const left = toPage(annotation.x[0], annotation.y) ;
                const right = toPage(annotation.x[1], annotation.y) ;
                const leg = annotation.legMm*pxPerMm ;
                const bracket = addPolyline(annotationLayer, [new Point(left.x, left.y + leg), left, right, new Point(right.x, right.y + leg)], spec.lineWidthPt) ;
                const symbol = addText(annotationLayer, annotation.text, annotationTextPt, (left.x + right.x)/2, left.y - annotation.textGapMm*pxPerMm, 'center-bottom', false) ;
                nodes = [bracket, symbol] ;
            }
            nodes.forEach((node, index) => {
                node.userDescription = nodes.length === 1 ? annotation.name : `${annotation.name} ${index === 0 ? 'bracket' : 'symbol'}` ;
            }) ;
        }

        // パネルを図の中の位置へ平行移動する（比較用の全体図も同じだけ動かす）
        const offset = { x: spec.offsetMm[0]*pxPerMm, y: spec.offsetMm[1]*pxPerMm } ;
        doc.executeCommand(DocumentCommand.createTransform(Selection.create(doc, [panelLayer, referenceLayer]), Transform.createTranslate(offset.x, offset.y))) ;
        panelLayers.push({ panel, layer: panelLayer, offset }) ;
        console.log(`[panel ${panel}] ${panelLayer.children.toArray().map((layer) => `${layer.userDescription.slice(panel.length + 2)}(${layer.children.toArray().length})`).join(', ')}; split ${splitCount}; offset ${spec.offsetMm.join(', ')} mm`) ;
    }
    setCurrent(firstSpread) ;
    removeTemporaryLayers(temporaryLayers) ; // 1 ページに並べた PDF のときの一時的なレイヤー（page N）
    doc.setVisible(false, Selection.create(doc, notesLayer)) ;

    // ---- パネル記号（Labels、最前面）----
    setCurrent(firstSpread) ;
    const labelsLayer = addLayer(firstSpread, 'Labels') ;
    const panelLabelSizePt = figure.panels.map((spec) => spec.fontSizePt?.panelLabel).find((size) => size) ?? defaultPanelLabelSizePt ;
    for (const item of panelLayers) {
        const label = addText(labelsLayer, item.panel, panelLabelSizePt, item.offset.x + panelLabelInsetMm[0]*pxPerMm, item.offset.y + panelLabelInsetMm[1]*pxPerMm, 'left-top', true) ;
        label.userDescription = item.panel ;
    }

    // ---- ページを Figure area に合わせる、確認、保存と書き出し ----
    doc.setSpreadSizeWithAnchor(firstSpread, areaWidth, areaHeight, SpatialAnchor.TopLeft) ;
    const pageBox = firstSpread.getSpreadBaseBox() ;
    const contentBoxes = panelLayers.map((item) => item.layer.getSpreadVisibleBox()) ;
    const right = Math.max(...contentBoxes.map((box) => box.x + box.width)) ;
    const bottom = Math.max(...contentBoxes.map((box) => box.y + box.height)) ;
    console.log(`[figure area] page ${(pageBox.width/pxPerMm).toFixed(2)} x ${(pageBox.height/pxPerMm).toFixed(2)} mm; panels extend to x ${(right/pxPerMm).toFixed(2)} mm, y ${(bottom/pxPerMm).toFixed(2)} mm`) ;
    console.log(`[layers] ${firstSpread.children.toArray().slice().reverse().map((node) => node.userDescription).join(' > ')}`) ;
    try {
        doc.saveAs(joinPath(savedDir, `${figure.name}.af`)) ;
        console.log(`[save] ${joinPath(savedDir, `${figure.name}.af`)}`) ;
    } catch (error) {
        console.log(`[save] exception ${error.message}`) ;
    }
    const firstPage = FileExportArea.createForPages('1') ;
    for (const [fileName, presetName] of [[`${figure.name}.pdf`, pdfExportPresetName], [`${figure.name}.png`, 'PNG']]) {
        const records = doc.export(joinPath(exportDir, fileName), FileExportOptions.createWithPresetName(presetName), firstPage) ;
        for (const record of records.all) {
            console.log(`[export] ${fileName}: ${record.isSuccess ? 'OK' : `NG ${record.errorMessage}`}`) ;
        }
    }
    try {
        fs.rename(joinPath(exportDir, `${figure.name}_1.png`), joinPath(exportDir, `${figure.name}.png`)) ;
    } catch (error) {
        // 1 ページの文書（1 ページに並べた PDF から組み立てたもの）では _1 が付かないので、ファイルがないのは正常
        if (!/NO_SUCH_FILE/.test(error.message)) {
            console.log(`[export] rename png: ${error.message}`) ;
        }
    }
    console.log(`uuid=${doc.sessionUuid}`) ;
}

const figure = JSON.parse(File.readAll(joinPath(inputDir, `${figureName}.json`)).toString()) ;
composeFigure(figure) ;
