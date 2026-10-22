// パネルのスタイル調整（スクリプトパネル用。スクリプトパネルに「Panel style」として登録した panel_style_loader.js が読み込んで実行する）
//
// 使い方（スクリプトパネルから）：affinity/compose の組み立てスクリプト（compose_single_panels.js・compose_test_figure.js）の規則で組み立てた図を開いて実行する。ダイアログで値を変えると画面に仮に反映され
// （プレビュー）、OK で確定、キャンセルで元に戻る。確定した変更は 1 回の取り消しで戻せる。
// 各欄の初期値は現在の値で、初期値から変えた欄だけを適用する（「変えない」の選択肢は置かない：2026-10-19、ユーザーの指定）。
// ダイアログの構成：
//   左の列「Text (all panels)」：文字のまとまり（目盛り・軸ラベル・凡例・注釈・その他）ごとのフォントと大きさ。全パネル共通
//   右の欄「Panels」：パネル（A, B …）を選ぶと、そのパネルの欄だけが表示される（欄が多いときは複数の列に並べる）
//     - 点の大きさ（パネルごとの倍率）
//     - 系列ごと（`X: lines 系列`、`X: markers 系列`、`X: bands 系列`、`X: bars 系列` の同じ系列名をまとめる）：
//       系列の色（線・点・帯・棒・凡例の記号にまとめて適用）、帯の不透明度、棒の淡さ、データの線の太さと線種、点の塗りと枠線
//     - 有意差記号（`X: annotations` の「… symbol」）の文字・フォント・大きさ
// 色は Affinity の色の欄で選ぶ。論文でよく使うパレット（palettes/*.ase、palettes/make_ase_palettes.py）をスウォッチに読み込んでおくと、
// 色の欄のスウォッチから選べる。フォントの選択肢は「fontChoices」（よく使うものだけ。インストールされているものだけを表示する）。
//
// 対象の探し方：見開きの最上位の `Panel X` レイヤーと、その中の `X: 成分 系列` のサブレイヤー（docs/figure-panel-style.md の 4.1 節）。
// パネルの数や図の種類は問わない。規則に沿わないレイヤーは対象にしない。凡例の記号は、元の色が系列と同じものを系列の記号とみなす。
// Affinity での変更は、MATLAB で図を作り直すと失われる。作り直しても残したい値は MATLAB の作図スクリプトへ書き写す
// （点の大きさの倍率は、MATLAB の MarkerSize にそのまま掛ければよい）。
//
// 拡張のしかた：「2. 調整項目」に、下の形のオブジェクトを 1 つ作って operations に加える。ほかの部分は変えなくてよい。
//   id, scope                    設定のキー（MCP からの確認で使う）と、欄を置く場所（'figure'：左の列、'panel'：パネルごとの欄）
//   prepare(doc, model)          対象と元の値を集める（プレビューで値が変わるので、最初に 1 回だけ集める）。対象がなければ null
//   addControls(column, state)   scope 'figure'：左の列に欄を加え、欄のオブジェクトを返す
//   addPanelControls(layout, state, panel)  scope 'panel'：layout.nextColumn() で得た列にそのパネルの欄（グループ）を加え、
//                                欄のオブジェクトを返す。対象がなければ null
//   readSettings(controls, state) 欄の値を、ただのオブジェクト（設定）にする。初期値から変わっていない値は null にする
//   commands(doc, state, settings) 元の値を基準にした変更のコマンドの配列を返す（何度プレビューしても同じ結果になるように）
//   summary(state, settings)     確定した変更の説明（ログ用）
//
// MCP からの動作確認：globalThis.panelStyleTest = { documentTitle, settings: { text, series, significance }, mode } を先に定義すると、
// ダイアログを出さずにその設定を使う。mode は 'apply'（確定）または 'preview'（プレビューして onPreview を呼び、プレビューを消す）。

const { Document } = require('/document.js') ;
const { Dialog, DialogResult } = require('/dialog.js') ;
const { CompoundCommandBuilder, DocumentCommand } = require('/commands.js') ;
const { Transform } = require('/geometry.js') ;
const { Selection, TextSelection } = require('/selections.js') ;
const { StoryDelta } = require('/storydelta.js') ;
const { StoryRange } = require('/story.js') ;
const { GlyphAttDoubleType } = require('/glyphatts.js') ;
const { FontFamily } = require('/fonts.js') ;
const { FillDescriptor } = require('/fills.js') ;
const { LineStyle, LineStyleMask, LineType, LineCap } = require('/linestyle.js') ;
const { Colour } = require('/colours.js') ;
const { UnitType } = require('/units.js') ;


// ---------------------------------------------------------------
// 1. ドキュメントの読み取り（レイヤー名の規則）と共通の関数
// ---------------------------------------------------------------

// サブレイヤー名の「成分」。長いものから順に照合し、残りを系列名とする（例：'A: markers high school' → markers, 'high school'）
const componentKinds = [
    'confidence band', 'tick labels', 'axis labels', 'axes lines', 'error bars', 'fit line',
    'annotations', 'legend', 'markers', 'events', 'lines', 'bands', 'bars',
] ;

function parseSubLayerName(name, panel) {
    const prefix = `${panel}: ` ;
    if (!name || !name.startsWith(prefix)) {
        return null ;
    }
    const rest = name.slice(prefix.length) ;
    const kind = componentKinds.find((candidate) => rest === candidate || rest.startsWith(`${candidate} `)) ?? rest ;
    return { kind, series: rest.slice(kind.length).trim() } ;
}

// パネルのある見開き：現在の見開きを優先し、なければパネルのある最初の見開き（compose_single_panels.js の図は 2 ページ目以降が空のページ）
function findPanelSpread(doc) {
    const hasPanels = (spread) => spread.children.toArray().some((layer) => /^Panel \S+$/.test(layer.userDescription ?? '')) ;
    if (hasPanels(doc.currentSpread)) {
        return doc.currentSpread ;
    }
    return doc.spreads.toArray().find(hasPanels) ?? null ;
}

// 見開きのパネルと、その中のサブレイヤーの一覧（パネル記号の順に並べる）
function scanDocument(spread) {
    const panels = [] ;
    for (const layer of spread.children.toArray()) {
        const match = /^Panel (\S+)$/.exec(layer.userDescription ?? '') ;
        if (!match) {
            continue ;
        }
        const panel = match[1] ;
        const subLayers = [] ;
        for (const subLayer of layer.children.toArray()) {
            const parsed = parseSubLayerName(subLayer.userDescription, panel) ;
            if (parsed) {
                subLayers.push({ node: subLayer, name: subLayer.userDescription, ...parsed }) ;
            }
        }
        panels.push({ panel, node: layer, subLayers }) ;
    }
    panels.sort((a, b) => (a.panel < b.panel ? -1 : 1)) ;
    return { panels } ;
}

const childrenOf = (node) => node.children.toArray() ;
const isOk = (result) => (result?.value ?? result) == DialogResult.Ok.value ;
const rgbaOf = (descriptor) => descriptor?.fill?.colour?.rgba8 ?? null ;
const sameRgb = (a, b) => a && b && a.r === b.r && a.g === b.g && a.b === b.b ;
const rgbText = (rgb) => (rgb ? `(${rgb.r},${rgb.g},${rgb.b})` : '-') ;
const colourFrom = (rgb, alpha = 255) => Colour.createRGBA8({ r: rgb.r, g: rgb.g, b: rgb.b, alpha: Math.round(alpha) }) ;
const black = { r: 0, g: 0, b: 0 } ;
const changed = (value, initial, tolerance = 0.005) => Math.abs(value - initial) > tolerance ;
const transformScale = (transform) => {
    const parts = transform.decompose() ;
    return (Math.abs(parts.scaleX) + Math.abs(parts.scaleY))/2 ;
} ;
const compound = (commands) => {
    const builder = CompoundCommandBuilder.create() ;
    for (const command of commands) {
        builder.addCommand(command) ;
    }
    return builder.createCommand() ;
} ;
// 文字の範囲：準備のときに読んだ元の範囲を使う（プレビュー中に読むと、プレビュー後の文字の範囲になるため。
// 2026-10-19、記号の文字を変えた後に大きさを変えると元の文字が一部残る不具合の修正）。
// 文字を置き換えた後の範囲は、元の範囲の長さを文字数の差だけ変えたもの（範囲は末尾の段落の区切りを含み、文字数より 1 長い）
function storyRangeOf(item, text = null) {
    return text == null ? item.range : new StoryRange(item.range.begin, item.range.end - item.fullText.length + text.length) ;
}
function storySelection(doc, items, text = null) {
    const selection = Selection.create(doc, items.map((item) => item.node)) ;
    for (const item of items) {
        selection.addSubSelectionForNode(item.node, TextSelection.create(storyRangeOf(item, text))) ;
    }
    return selection ;
}
function pointOf(box, anchor) {
    const [horizontal, vertical] = anchor.split('-') ;
    return {
        x: { left: box.x, center: box.x + box.width/2, right: box.x + box.width }[horizontal],
        y: { top: box.y, middle: box.y + box.height/2, bottom: box.y + box.height }[vertical],
    } ;
}
// コマンドを試しにプレビューして外形を測り、プレビューを消す（変更後の位置の計算に使う）
function measureWithPreview(doc, commands, nodes) {
    doc.executeCommand(compound(commands), true) ;
    const boxes = nodes.map((node) => node.getSpreadBaseBox()) ;
    doc.clearPreviews() ;
    return boxes ;
}
// 文字の原点（大きさを変えても動かない点）：試しに 1.5 倍にしたプレビューの外形から求める
function textOrigins(doc, items, pxPerPt) {
    const trialScale = 1.5 ;
    const trial = measureWithPreview(doc, items.map((item) => DocumentCommand.createFormatText(storySelection(doc, [item]),
        StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, item.sizePt*trialScale*pxPerPt))), items.map((item) => item.node)) ;
    items.forEach((item, index) => {
        const box = trial[index] ;
        const scale = (box.width + box.height)/(item.box.width + item.box.height) ;
        item.fixed = { x: (box.x - scale*item.box.x)/(1 - scale), y: (box.y - scale*item.box.y)/(1 - scale) } ;
    }) ;
}
// 大きさの変更後の外形：原点を中心に拡大縮小した外形
function scaledBox(base, fixed, scale) {
    return {
        x: fixed.x + scale*(base.x - fixed.x),
        y: fixed.y + scale*(base.y - fixed.y),
        width: scale*base.width,
        height: scale*base.height,
    } ;
}
function textItem(node, pxPerPt) {
    const atts = node.story.getGlyphAtts(0) ;
    return {
        node,
        range: node.storyRange, // 元の文字の範囲（storySelection で使う）
        fullText: node.text,
        box: node.getSpreadBaseBox(),
        sizePt: atts.height*transformScale(node.baseToSpreadTransform)/pxPerPt,
        family: atts.font.familyName,
    } ;
}
// 色の欄：初期値は現在の色。値が初期値から変わったときだけ、その色（RGB）を返す
function addColourField(group, label, initialRgb) {
    const initial = initialRgb ?? black ;
    const picker = group.addColourPicker(label, colourFrom(initial)) ;
    return {
        read() {
            const value = picker.value?.rgba8 ;
            return value && !sameRgb(value, initial) ? { r: value.r, g: value.g, b: value.b } : null ;
        },
    } ;
}


// ---------------------------------------------------------------
// 2. 調整項目
// ---------------------------------------------------------------

// 2.0 フォントの選択肢：学術論文でよく使う英字・和文のゴシックと明朝（2026-10-19、ユーザーの指定）。インストールされているものだけを表示する
const fontChoices = [
    { family: 'Arial', label: 'Arial (sans)' },
    { family: 'Helvetica', label: 'Helvetica (sans)' },
    { family: 'Times New Roman', label: 'Times New Roman (serif)' },
    { family: 'Century', label: 'Century (serif)' },
    { family: 'Yu Gothic', label: 'Yu Gothic 游ゴシック' },
    { family: 'MS Gothic', label: 'MS Gothic MS ゴシック' },
    { family: 'Hiragino Sans', label: 'Hiragino Sans ヒラギノ角ゴ' },
    { family: 'Yu Mincho', label: 'Yu Mincho 游明朝' },
    { family: 'MS Mincho', label: 'MS Mincho MS 明朝' },
    { family: 'Hiragino Mincho ProN', label: 'Hiragino Mincho ヒラギノ明朝' },
] ;
let installedFontsCache = null ;
function installedFonts() {
    if (!installedFontsCache) {
        const installed = new Set(FontFamily.all.map((family) => family.name)) ;
        installedFontsCache = fontChoices.filter((choice) => installed.has(choice.family)) ;
    }
    return installedFontsCache ;
}
// フォントの欄：先頭は現在のフォント（変えない）。選んだときだけそのフォント名を返す
function addFontField(group, fonts, currentFamilies) {
    const field = group.addComboBox('Font', [`(current: ${currentFamilies.join(', ')})`, ...fonts.map((font) => font.label)], 0) ;
    return { read: () => (field.selectedIndex > 0 ? fonts[field.selectedIndex - 1].family : null) } ;
}

// 2.1 文字（全パネル共通）：まとまりごとのフォントと大きさ
const textCategories = [
    { key: 'tick labels', label: 'Tick labels', kinds: ['tick labels'] },
    { key: 'axis labels', label: 'Axis labels', kinds: ['axis labels'] },
    { key: 'legend', label: 'Legend', kinds: ['legend'] },
    { key: 'annotations', label: 'Annotations', kinds: ['annotations'] }, // 有意差記号は 2.3 で扱うので除く
    { key: 'other', label: 'Other text', kinds: null }, // 上以外のサブレイヤーの文字（イベント線の名前など）
] ;
const isSignificanceSymbol = (node) => / symbol$/.test(node.userDescription ?? '') ;

// 大きさを変えたときに動かさない点：軸に向いた側を保つ（目盛り・軸ラベルと軸の間隔が変わらないように）
//   目盛り：右揃え（縦軸）は右・中央、中央揃え（横軸）は中央・上、左揃えは左・中央
//   軸ラベル：回転した縦軸のラベルは軸に向いた側（-90° なら右）、横書きは軸より下なら上、上（タイトル）なら下
//   凡例：左・中央。その他：揃えの側・中央
function anchorFor(categoryKey, node, box, axesBox) {
    const alignIndex = node.story.getParagraphAtts(0).alignXType.value ;
    const horizontal = ['left', 'center', 'right'][alignIndex] ?? 'left' ;
    const rotation = node.baseToSpreadTransform.decompose().rotation ?? 0 ;
    if (categoryKey === 'tick labels') {
        return horizontal === 'center' ? 'center-top' : `${horizontal}-middle` ;
    }
    if (categoryKey === 'axis labels') {
        if (Math.abs(rotation) > 0.1) {
            return rotation < 0 ? 'right-middle' : 'left-middle' ;
        }
        const centreY = box.y + box.height/2 ;
        return axesBox && centreY < axesBox.y ? 'center-bottom' : 'center-top' ;
    }
    if (categoryKey === 'legend') {
        return 'left-middle' ;
    }
    return `${horizontal}-middle` ;
}

const textOperation = {
    id: 'text',
    scope: 'figure',

    prepare(doc, model) {
        const pxPerPt = doc.dpi/72 ;
        const categories = [] ;
        for (const category of textCategories) {
            const items = [] ;
            for (const panel of model.panels) {
                const axesLayer = panel.subLayers.find((subLayer) => subLayer.kind === 'axes lines') ;
                const axesBox = axesLayer ? axesLayer.node.getSpreadVisibleBox() : null ;
                for (const subLayer of panel.subLayers) {
                    const inCategory = category.kinds
                        ? category.kinds.includes(subLayer.kind)
                        : !textCategories.some((other) => other.kinds?.includes(subLayer.kind)) ;
                    if (!inCategory) {
                        continue ;
                    }
                    for (const node of childrenOf(subLayer.node).filter((child) => child.isTextNode && !isSignificanceSymbol(child))) {
                        const item = textItem(node, pxPerPt) ;
                        item.anchor = anchorFor(category.key, node, item.box, axesBox) ;
                        items.push(item) ;
                    }
                }
            }
            if (items.length > 0) {
                const counts = new Map() ;
                for (const item of items) {
                    const key = Number(item.sizePt.toFixed(2)) ;
                    counts.set(key, (counts.get(key) ?? 0) + 1) ;
                }
                const sizePt = [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0] ; // 最も多い大きさ
                categories.push({ ...category, items, sizePt, families: [...new Set(items.map((item) => item.family))] }) ;
            }
        }
        if (categories.length === 0) {
            return null ;
        }
        textOrigins(doc, categories.flatMap((category) => category.items), pxPerPt) ;
        return { categories, fonts: installedFonts(), pxPerPt, familyBoxes: {} } ;
    },

    // フォントを変えたときの外形（フォントによって字形の外形が違うので、動かさない点の計算に使う）。まとまりとフォントの組ごとに覚える
    familyBoxesFor(doc, state, category, family) {
        const key = `${category.key}\n${family}` ;
        if (!state.familyBoxes[key]) {
            const nodes = category.items.map((item) => item.node) ;
            state.familyBoxes[key] = measureWithPreview(doc, [DocumentCommand.createFormatText(storySelection(doc, category.items), StoryDelta.createFamilyName(family))], nodes) ;
        }
        return state.familyBoxes[key] ;
    },

    addControls(column, state) {
        const controls = {} ;
        column.addGroup('Text (all panels)').addStaticText(null, 'Font and size for each group of text in all panels.') ;
        for (const category of state.categories) {
            const group = column.addGroup(`${category.label} (${category.items.length})`) ;
            controls[category.key] = {
                font: addFontField(group, state.fonts, category.families),
                size: group.addUnitValueEditor('Size (pt)', UnitType.Number, UnitType.Number, category.sizePt, 4, 24).setPrecision(2),
            } ;
        }
        return controls ;
    },

    readSettings(controls, state) {
        const groups = {} ;
        for (const category of state.categories) {
            const c = controls[category.key] ;
            groups[category.key] = {
                family: c.font.read(),
                sizePt: changed(c.size.value, category.sizePt) ? c.size.value : null,
            } ;
        }
        return { groups } ;
    },

    commands(doc, state, settings) {
        const commands = [] ;
        for (const category of state.categories) {
            const s = settings?.groups?.[category.key] ;
            if (!s || (!s.family && !s.sizePt)) {
                continue ;
            }
            // 変更後の外形を求め、動かさない点（anchor）が元の位置に来るように平行移動する
            const familyBoxes = s.family ? this.familyBoxesFor(doc, state, category, s.family) : null ;
            if (s.family) {
                commands.push(DocumentCommand.createFormatText(storySelection(doc, category.items), StoryDelta.createFamilyName(s.family))) ;
            }
            if (s.sizePt) {
                commands.push(DocumentCommand.createFormatText(storySelection(doc, category.items), StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, s.sizePt*state.pxPerPt))) ;
            }
            category.items.forEach((item, index) => {
                const newBox = scaledBox(familyBoxes ? familyBoxes[index] : item.box, item.fixed, s.sizePt ? s.sizePt/item.sizePt : 1) ;
                const before = pointOf(item.box, item.anchor) ;
                const after = pointOf(newBox, item.anchor) ;
                commands.push(DocumentCommand.createTransform(Selection.create(doc, item.node), Transform.createTranslate(before.x - after.x, before.y - after.y))) ;
            }) ;
        }
        return commands ;
    },

    summary(state, settings) {
        const lines = [] ;
        for (const category of state.categories) {
            const s = settings?.groups?.[category.key] ;
            const parts = [] ;
            if (s?.family) {
                parts.push(`font ${category.families.join('/')} -> ${s.family}`) ;
            }
            if (s?.sizePt) {
                parts.push(`size ${category.sizePt} -> ${s.sizePt} pt`) ;
            }
            if (parts.length > 0) {
                lines.push(`text ${category.key} (${category.items.length}): ${parts.join(', ')}`) ;
            }
        }
        return lines.length > 0 ? lines.join('\n') : null ;
    },
} ;

// 2.2 系列（パネルごと）：系列の色、帯の不透明度、棒の淡さ、データの線の太さと線種、点の大きさ・塗り・枠線
// 同じ系列名のサブレイヤー（lines・markers・bands・bars）を 1 つの系列にまとめる。回帰直線と信頼帯は系列「regression」。
// 系列の色は、線の色・点の塗り・帯の塗り・棒の塗りと、元の色が同じ凡例の記号に適用する（帯・棒は系列の色の同系色：2026-10-19、ユーザーの指定）。
//   帯：系列の色に不透明度をかける（不透明度は別の欄。透明度のない帯は、白の上で同じ見た目になる不透明度に読み替える）
//   棒：系列の色と白を混ぜた淡い色（淡さは別の欄。色の割合 [%]）
// 線は帯より前面にある（compose_single_panels.js は帯のサブレイヤーを線より背面に作る）。
// 点の大きさは各点の外形の中心を基準に変える（点の位置＝データの値は動かない）。枠線の幅は拡大縮小では変わらない。
// 形による点の大きさの違い（MATLAB の四角は丸より小さい）は扱わない（手直しと個別の依頼で対応する：2026-10-18 決定）
const lineStyles = {
    solid: { type: LineType.Solid, dashPattern: [], cap: LineCap.Butt },
    dash: { type: LineType.Dash, dashPattern: [4, 2], cap: LineCap.Butt }, // 線の幅を単位とする長さ（線 4・間 2）
    dot: { type: LineType.Dash, dashPattern: [0, 2], cap: LineCap.Round },
    dashdot: { type: LineType.Dash, dashPattern: [4, 2, 0, 2], cap: LineCap.Round },
} ;
const lineStyleKeys = ['solid', 'dash', 'dot', 'dashdot'] ;
const lineStyleItems = ['Solid', 'Dash', 'Dot', 'Dash-dot'] ;
// 現在の線種：実線か、破線の長さの並び（Affinity は 0 を 0.05 にする）から判定する。判定できなければ null
function lineStyleKeyOf(node) {
    const style = node.lineStyle ;
    if ((style.type?.value ?? style.type) === LineType.Solid.value) {
        return 'solid' ;
    }
    const pattern = (style.dashPattern ?? []).map((value) => (value < 0.1 ? 0 : value)) ;
    return lineStyleKeys.find((key) => JSON.stringify(lineStyles[key].dashPattern) === JSON.stringify(pattern)) ?? null ;
}
// 塗りの色が、系列の色と白を何 % ずつ混ぜた色か（棒の淡さ・透明度のない帯の読み替えに使う）
function tintPercentOf(fill, colour) {
    const ratios = ['r', 'g', 'b'].filter((key) => 255 - colour[key] > 20).map((key) => (255 - fill[key])/(255 - colour[key])) ;
    return ratios.length > 0 ? Math.min(100, Math.max(0, Math.round(100*ratios.reduce((a, b) => a + b)/ratios.length))) : 100 ;
}
const tint = (rgb, percent) => ({
    r: Math.round(rgb.r*percent/100 + 255*(1 - percent/100)),
    g: Math.round(rgb.g*percent/100 + 255*(1 - percent/100)),
    b: Math.round(rgb.b*percent/100 + 255*(1 - percent/100)),
}) ;

const seriesOperation = {
    id: 'series',
    scope: 'panel',

    prepare(doc, model) {
        const pxPerPt = doc.dpi/72 ;
        const panels = [] ;
        for (const panel of model.panels) {
            const seriesMap = new Map() ;
            const seriesOf = (name) => {
                if (!seriesMap.has(name)) {
                    seriesMap.set(name, { name, lines: [], markers: [], bands: [], bars: [], legendLines: [], legendMarkers: [] }) ;
                }
                return seriesMap.get(name) ;
            } ;
            for (const subLayer of panel.subLayers) {
                const nodes = childrenOf(subLayer.node).filter((node) => node.isVectorNode) ;
                const regression = subLayer.kind === 'fit line' || subLayer.kind === 'confidence band' ;
                const name = regression ? 'regression' : subLayer.series ;
                if (subLayer.kind === 'lines' || subLayer.kind === 'fit line') {
                    seriesOf(name).lines.push(...nodes) ;
                } else if (subLayer.kind === 'markers') {
                    seriesOf(name).markers.push(...nodes) ;
                } else if (subLayer.kind === 'bands' || subLayer.kind === 'confidence band') {
                    seriesOf(name).bands.push(...nodes) ;
                } else if (subLayer.kind === 'bars') {
                    // 棒は塗りと枠線が別のオブジェクト。塗りのあるものだけを色の対象にする
                    seriesOf(name).bars.push(...nodes.filter((node) => node.hasBrushFill && rgbaOf(node.brushFillDescriptor)?.alpha > 0)) ;
                }
            }
            const series = [...seriesMap.values()].filter((item) => item.lines.length + item.markers.length + item.bands.length + item.bars.length > 0) ;
            if (series.length === 0) {
                continue ;
            }
            // 元の色・線の太さと線種・点の大きさと中心・塗りと枠線・帯の不透明度・棒の淡さ
            for (const item of series) {
                const firstLine = item.lines[0] ;
                const firstMarker = item.markers[0] ;
                item.lineColour = firstLine && firstLine.hasPenFill ? rgbaOf(firstLine.penFillDescriptor) : null ;
                item.lineWeightPt = firstLine ? firstLine.lineWeight*transformScale(firstLine.localToSpreadTransform)/pxPerPt : null ;
                item.lineStyle = firstLine ? lineStyleKeyOf(firstLine) : null ;
                item.markerColour = firstMarker && firstMarker.hasBrushFill ? rgbaOf(firstMarker.brushFillDescriptor) : null ;
                item.markerHollow = firstMarker ? !firstMarker.hasBrushFill || !(rgbaOf(firstMarker.brushFillDescriptor)?.alpha > 0) : false ;
                const hasEdge = firstMarker && firstMarker.hasPenFill && firstMarker.lineWeight > 0 ;
                item.edgeColour = hasEdge ? rgbaOf(firstMarker.penFillDescriptor) : null ;
                item.edgeWidthPt = hasEdge ? firstMarker.lineWeight*transformScale(firstMarker.localToSpreadTransform)/pxPerPt : 0 ;
                item.markerBoxes = item.markers.map((node) => node.getSpreadBaseBox()) ;
                item.markerSizePt = item.markerBoxes.length > 0 ? item.markerBoxes[0].width/pxPerPt : 0 ;
                const bandFill = item.bands[0] ? rgbaOf(item.bands[0].brushFillDescriptor) : null ;
                item.colour = item.lineColour ?? item.markerColour ?? (bandFill && bandFill.alpha < 255 ? bandFill : null) ?? black ;
                item.bandOpacity = bandFill ? (bandFill.alpha < 255 ? Math.round(100*bandFill.alpha/255) : tintPercentOf(bandFill, item.colour)) : null ;
                const barFill = item.bars[0] ? rgbaOf(item.bars[0].brushFillDescriptor) : null ;
                item.barTint = barFill ? tintPercentOf(barFill, item.colour) : null ;
            }
            // 凡例の記号：元の色が系列の線の色・点の色と同じもの
            const legendLayer = panel.subLayers.find((subLayer) => subLayer.kind === 'legend') ;
            if (legendLayer) {
                for (const node of childrenOf(legendLayer.node).filter((child) => child.isVectorNode)) {
                    const pen = node.hasPenFill && node.lineWeight > 0 ? rgbaOf(node.penFillDescriptor) : null ;
                    const fill = node.hasBrushFill ? rgbaOf(node.brushFillDescriptor) : null ;
                    for (const item of series) {
                        if (pen && sameRgb(pen, item.lineColour)) {
                            item.legendLines.push(node) ;
                        } else if (fill && sameRgb(fill, item.markerColour)) {
                            item.legendMarkers.push(node) ;
                        }
                    }
                }
            }
            panels.push({ panel: panel.panel, series, hasMarkers: series.some((item) => item.markers.length > 0) }) ;
        }
        return panels.length > 0 ? { panels, pxPerPt } : null ;
    },

    addPanelControls(layout, state, panel) {
        const panelState = state.panels.find((item) => item.panel === panel) ;
        if (!panelState) {
            return null ;
        }
        let scale = null ;
        if (panelState.hasMarkers) {
            scale = layout.nextColumn().addGroup(`${panel}: markers (all series)`)
                .addUnitValueEditor('Marker size (%)', UnitType.Number, UnitType.Number, 100, 10, 500).setPrecision(0) ;
        }
        const series = {} ;
        for (const item of panelState.series) {
            const parts = ['lines', 'markers', 'bands', 'bars'].filter((key) => item[key].length > 0) ;
            const group = layout.nextColumn().addGroup(`${panel}: ${item.name} (${parts.join(', ')})`) ;
            const c = { colour: addColourField(group, 'Colour', item.colour) } ;
            if (item.lines.length > 0) {
                c.lineWidth = group.addUnitValueEditor('Line width (pt)', UnitType.Number, UnitType.Number, Number(item.lineWeightPt.toFixed(2)), 0.1, 10).setPrecision(2) ;
                c.lineStyle = group.addComboBox('Line style', lineStyleItems, Math.max(0, lineStyleKeys.indexOf(item.lineStyle ?? 'solid'))) ;
            }
            if (item.bands.length > 0) {
                c.bandOpacity = group.addUnitValueEditor('Band opacity (%)', UnitType.Number, UnitType.Number, item.bandOpacity, 0, 100).setPrecision(0) ;
            }
            if (item.bars.length > 0) {
                c.barTint = group.addUnitValueEditor('Bar colour (%)', UnitType.Number, UnitType.Number, item.barTint, 0, 100).setPrecision(0) ;
            }
            if (item.markers.length > 0) {
                c.markerFill = group.addComboBox('Marker fill', ['Filled', 'Hollow'], item.markerHollow ? 1 : 0) ;
                c.edgeColour = addColourField(group, 'Marker edge colour', item.edgeColour ?? black) ;
                c.edgeWidth = group.addUnitValueEditor('Marker edge width (pt, 0 = none)', UnitType.Number, UnitType.Number, Number(item.edgeWidthPt.toFixed(2)), 0, 5).setPrecision(2) ;
            }
            series[item.name] = c ;
        }
        return { scale, series } ;
    },

    readSettings(controls, state) {
        const panels = {} ;
        for (const panel of state.panels) {
            const panelControls = controls[panel.panel] ;
            if (!panelControls) {
                continue ;
            }
            const series = {} ;
            for (const item of panel.series) {
                const c = panelControls.series[item.name] ;
                const lineStyle = c.lineStyle ? lineStyleKeys[c.lineStyle.selectedIndex] : null ;
                const hollow = c.markerFill ? c.markerFill.selectedIndex === 1 : null ;
                series[item.name] = {
                    colour: c.colour.read(),
                    lineWidthPt: c.lineWidth && changed(c.lineWidth.value, Number(item.lineWeightPt.toFixed(2))) ? c.lineWidth.value : null,
                    lineStyle: lineStyle && lineStyle !== (item.lineStyle ?? 'solid') ? lineStyle : null,
                    bandOpacity: c.bandOpacity && changed(c.bandOpacity.value, item.bandOpacity, 0.5) ? c.bandOpacity.value : null,
                    barTint: c.barTint && changed(c.barTint.value, item.barTint, 0.5) ? c.barTint.value : null,
                    markerHollow: hollow !== null && hollow !== item.markerHollow ? hollow : null,
                    edgeColour: c.edgeColour ? c.edgeColour.read() : null,
                    edgeWidthPt: c.edgeWidth && changed(c.edgeWidth.value, Number(item.edgeWidthPt.toFixed(2))) ? c.edgeWidth.value : null,
                } ;
            }
            panels[panel.panel] = { scalePercent: panelControls.scale ? panelControls.scale.value : 100, series } ;
        }
        return { panels } ;
    },

    commands(doc, state, settings) {
        const commands = [] ;
        const selectionOf = (nodes) => Selection.create(doc, nodes) ;
        const setLineWeight = (nodes, weightPt) => {
            const lineStyle = LineStyle.createDefault() ;
            lineStyle.weight = weightPt*state.pxPerPt ;
            commands.push(DocumentCommand.createSetLineStyle(selectionOf(nodes), lineStyle, { lineStyleMask: LineStyleMask.Weight })) ;
        } ;
        for (const panel of state.panels) {
            const panelSettings = settings?.panels?.[panel.panel] ;
            if (!panelSettings) {
                continue ;
            }
            const scale = (panelSettings.scalePercent ?? 100)/100 ;
            for (const item of panel.series) {
                const s = panelSettings.series?.[item.name] ?? {} ;
                const colour = s.colour ?? null ;
                const seriesColour = colour ?? item.colour ;
                // 線：色、太さ、線種（凡例の線の記号にも同じものを適用する）。破線は「均等割り」を使わない
                // （MATLAB の曲線は短い線分の集まりで、均等割りでは線分ごとに破線の長さが調整され、間隔が不揃いになるため：2026-10-19）
                const lineNodes = [...item.lines, ...item.legendLines] ;
                if (lineNodes.length > 0) {
                    if (colour) {
                        commands.push(DocumentCommand.createSetPenFill(selectionOf(lineNodes), colourFrom(colour))) ;
                    }
                    if (s.lineWidthPt) {
                        setLineWeight(lineNodes, s.lineWidthPt) ;
                    }
                    if (s.lineStyle) {
                        const style = lineStyles[s.lineStyle] ;
                        commands.push(DocumentCommand.createSetLineStyle(selectionOf(lineNodes),
                            LineStyle.create({ type: style.type, dashPattern: style.dashPattern, cap: style.cap, balancedDashes: false }),
                            { lineStyleMask: LineStyleMask.Type | LineStyleMask.DashPattern | LineStyleMask.Cap | LineStyleMask.BalancedDashes })) ;
                    }
                }
                // 帯：系列の色に不透明度をかける。棒：系列の色と白を混ぜた淡い色
                if (item.bands.length > 0 && (colour || s.bandOpacity !== null && s.bandOpacity !== undefined)) {
                    const opacity = s.bandOpacity ?? item.bandOpacity ;
                    commands.push(DocumentCommand.createSetBrushFill(selectionOf(item.bands), colourFrom(seriesColour, 255*opacity/100))) ;
                }
                if (item.bars.length > 0 && (colour || s.barTint !== null && s.barTint !== undefined)) {
                    commands.push(DocumentCommand.createSetBrushFill(selectionOf(item.bars), colourFrom(tint(seriesColour, s.barTint ?? item.barTint)))) ;
                }
                // 点：大きさ（元の中心を基準に拡大縮小）、塗り、枠線（凡例の点の記号には塗りと枠線だけを適用する）
                if (item.markers.length > 0) {
                    if (Math.abs(scale - 1) > 1e-6) {
                        item.markers.forEach((node, index) => {
                            const box = item.markerBoxes[index] ;
                            commands.push(DocumentCommand.createTransform(selectionOf([node]),
                                Transform.createScale(scale, scale).around(box.x + box.width/2, box.y + box.height/2))) ;
                        }) ;
                    }
                    const markerNodes = [...item.markers, ...item.legendMarkers] ;
                    const hollow = s.markerHollow ?? item.markerHollow ;
                    if (hollow && s.markerHollow) {
                        commands.push(DocumentCommand.createSetBrushFill(selectionOf(markerNodes), FillDescriptor.createNone())) ;
                    } else if (!hollow && (colour || s.markerHollow === false)) {
                        commands.push(DocumentCommand.createSetBrushFill(selectionOf(markerNodes), colourFrom(seriesColour))) ;
                    }
                    // 枠線：幅 0 は枠線なし。白抜きにして枠線がなければ、系列の色の 0.5 pt にする（点が見えなくならないように）
                    let edgeWidth = s.edgeWidthPt ?? item.edgeWidthPt ;
                    let edgeColour = s.edgeColour ?? item.edgeColour ?? black ;
                    if (hollow && edgeWidth === 0) {
                        edgeWidth = 0.5 ;
                        edgeColour = s.edgeColour ?? seriesColour ;
                    }
                    const edgeChanged = s.edgeColour || s.edgeWidthPt !== null && s.edgeWidthPt !== undefined || (hollow && s.markerHollow) ;
                    if (edgeChanged) {
                        if (edgeWidth === 0) {
                            commands.push(DocumentCommand.createSetPenFill(selectionOf(markerNodes), FillDescriptor.createNone())) ;
                        } else {
                            commands.push(DocumentCommand.createSetPenFill(selectionOf(markerNodes), colourFrom(edgeColour))) ;
                            setLineWeight(markerNodes, edgeWidth) ;
                        }
                    }
                }
            }
        }
        return commands ;
    },

    summary(state, settings) {
        const lines = [] ;
        for (const panel of state.panels) {
            const panelSettings = settings?.panels?.[panel.panel] ;
            if (!panelSettings) {
                continue ;
            }
            const scalePercent = panelSettings.scalePercent ?? 100 ;
            for (const item of panel.series) {
                const s = panelSettings.series?.[item.name] ?? {} ;
                const parts = [] ;
                if (s.colour) {
                    parts.push(`colour ${rgbText(item.colour)} -> ${rgbText(s.colour)}`) ;
                }
                if (s.lineWidthPt) {
                    parts.push(`line width ${item.lineWeightPt.toFixed(2)} -> ${s.lineWidthPt} pt`) ;
                }
                if (s.lineStyle) {
                    parts.push(`line style ${item.lineStyle ?? '?'} -> ${s.lineStyle}`) ;
                }
                if (s.bandOpacity !== null && s.bandOpacity !== undefined) {
                    parts.push(`band opacity ${item.bandOpacity} -> ${s.bandOpacity} %`) ;
                }
                if (s.barTint !== null && s.barTint !== undefined) {
                    parts.push(`bar colour ${item.barTint} -> ${s.barTint} %`) ;
                }
                if (item.markers.length > 0 && Math.abs(scalePercent - 100) > 1e-6) {
                    parts.push(`marker size ${item.markerSizePt.toFixed(2)} -> ${(item.markerSizePt*scalePercent/100).toFixed(2)} pt (MATLAB MarkerSize x${(scalePercent/100).toFixed(2)})`) ;
                }
                if (s.markerHollow !== null && s.markerHollow !== undefined) {
                    parts.push(`marker ${s.markerHollow ? 'hollow' : 'filled'}`) ;
                }
                if (s.edgeColour || (s.edgeWidthPt !== null && s.edgeWidthPt !== undefined)) {
                    parts.push(`edge ${rgbText(s.edgeColour ?? item.edgeColour)} ${s.edgeWidthPt ?? item.edgeWidthPt.toFixed(2)} pt`) ;
                }
                if (parts.length > 0) {
                    lines.push(`${panel.panel}: ${item.name}: ${parts.join(', ')}`) ;
                }
            }
        }
        return lines.length > 0 ? lines.join('\n') : null ;
    },
} ;

// 2.3 有意差記号（パネルごと）：記号の文字、フォント、大きさ
// 対象は `X: annotations` の中で名前が「… symbol」の文字（compose_single_panels.js・compose_test_figure.js が付ける名前）。文字は入力したものにパネル内のすべての記号を
// 置き換える（例：# や *。記号の数は区別しない：2026-10-19、ユーザーの指定）。大きさ・文字を変えても下端の中央（ブラケットとの間隔）を保つ
const significanceOperation = {
    id: 'significance',
    scope: 'panel',

    prepare(doc, model) {
        const pxPerPt = doc.dpi/72 ;
        const panels = [] ;
        for (const panel of model.panels) {
            const items = [] ;
            for (const subLayer of panel.subLayers.filter((layer) => layer.kind === 'annotations')) {
                for (const node of childrenOf(subLayer.node).filter((child) => child.isTextNode && isSignificanceSymbol(child))) {
                    const item = textItem(node, pxPerPt) ;
                    item.text = node.text.trim() ;
                    items.push(item) ;
                }
            }
            if (items.length > 0) {
                panels.push({ panel: panel.panel, items, text: items[0].text, families: [...new Set(items.map((item) => item.family))], sizePt: items[0].sizePt }) ;
            }
        }
        if (panels.length === 0) {
            return null ;
        }
        textOrigins(doc, panels.flatMap((panel) => panel.items), pxPerPt) ;
        return { panels, fonts: installedFonts(), pxPerPt, measured: {} } ;
    },

    // 記号の文字とフォントを変えたときの外形（試しのプレビューで測り、組ごとに覚える）
    boxesFor(doc, state, panelState, text, family) {
        const key = `${panelState.panel}\n${text ?? ''}\n${family ?? ''}` ;
        if (!state.measured[key]) {
            state.measured[key] = measureWithPreview(doc, this.textCommands(doc, state, panelState, text, family), panelState.items.map((item) => item.node)) ;
        }
        return state.measured[key] ;
    },

    // 文字の置き換えとフォントのコマンド（大きさの変更は含まない）
    textCommands(doc, state, panelState, text, family) {
        const commands = [] ;
        for (const item of panelState.items) {
            if (text) {
                commands.push(DocumentCommand.createSetText(storySelection(doc, [item]), text)) ;
                // 置き換えた文字の属性を、元のフォント（または指定のフォント）と元の大きさに揃える（範囲は置き換えた後の文字）
                commands.push(DocumentCommand.createFormatText(storySelection(doc, [item], text), StoryDelta.createFamilyName(family ?? item.family))) ;
                commands.push(DocumentCommand.createFormatText(storySelection(doc, [item], text), StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, item.sizePt*state.pxPerPt))) ;
            } else if (family) {
                commands.push(DocumentCommand.createFormatText(storySelection(doc, [item]), StoryDelta.createFamilyName(family))) ;
            }
        }
        return commands ;
    },

    addPanelControls(layout, state, panel) {
        const panelState = state.panels.find((item) => item.panel === panel) ;
        if (!panelState) {
            return null ;
        }
        const group = layout.nextColumn().addGroup(`${panel}: significance marks (${panelState.items.length})`) ;
        return {
            text: group.addTextBox('Mark', panelState.text),
            font: addFontField(group, state.fonts, panelState.families),
            size: group.addUnitValueEditor('Size (pt)', UnitType.Number, UnitType.Number, Number(panelState.sizePt.toFixed(2)), 4, 24).setPrecision(2),
        } ;
    },

    readSettings(controls, state) {
        const panels = {} ;
        for (const panelState of state.panels) {
            const c = controls[panelState.panel] ;
            if (!c) {
                continue ;
            }
            const text = (c.text.text ?? '').trim() ;
            panels[panelState.panel] = {
                text: text && text !== panelState.text ? text : null,
                family: c.font.read(),
                sizePt: changed(c.size.value, Number(panelState.sizePt.toFixed(2))) ? c.size.value : null,
            } ;
        }
        return { panels } ;
    },

    commands(doc, state, settings) {
        const commands = [] ;
        for (const panelState of state.panels) {
            const s = settings?.panels?.[panelState.panel] ;
            if (!s || (!s.text && !s.family && !s.sizePt)) {
                continue ;
            }
            const boxes = s.text || s.family ? this.boxesFor(doc, state, panelState, s.text, s.family) : null ;
            commands.push(...this.textCommands(doc, state, panelState, s.text, s.family)) ;
            if (s.sizePt) {
                commands.push(DocumentCommand.createFormatText(storySelection(doc, panelState.items, s.text),
                    StoryDelta.createGlyphDouble(GlyphAttDoubleType.Height, s.sizePt*state.pxPerPt))) ;
            }
            // 下端の中央（ブラケットとの間隔）を保つ
            panelState.items.forEach((item, index) => {
                const newBox = scaledBox(boxes ? boxes[index] : item.box, item.fixed, s.sizePt ? s.sizePt/item.sizePt : 1) ;
                const before = pointOf(item.box, 'center-bottom') ;
                const after = pointOf(newBox, 'center-bottom') ;
                commands.push(DocumentCommand.createTransform(Selection.create(doc, item.node), Transform.createTranslate(before.x - after.x, before.y - after.y))) ;
            }) ;
        }
        return commands ;
    },

    summary(state, settings) {
        const lines = [] ;
        for (const panelState of state.panels) {
            const s = settings?.panels?.[panelState.panel] ;
            const parts = [] ;
            if (s?.text) {
                parts.push(`mark "${panelState.text}" -> "${s.text}"`) ;
            }
            if (s?.family) {
                parts.push(`font -> ${s.family}`) ;
            }
            if (s?.sizePt) {
                parts.push(`size ${panelState.sizePt.toFixed(2)} -> ${s.sizePt} pt`) ;
            }
            if (parts.length > 0) {
                lines.push(`${panelState.panel}: significance marks: ${parts.join(', ')}`) ;
            }
        }
        return lines.length > 0 ? lines.join('\n') : null ;
    },
} ;

// 調整項目の一覧（ダイアログでは、この順に欄を並べる）
const operations = [textOperation, seriesOperation, significanceOperation] ;


// ---------------------------------------------------------------
// 3. 実行
// ---------------------------------------------------------------

const panelColumns = 3 ; // パネルの欄を並べる列の数（欄が多いパネルでも画面に収まるように）
const dialogWidth = 1150 ; // ダイアログの初期の幅 [px]（大きさは変えられる。SDK に縦のスクロールの設定はない）

// 全項目のコマンドを 1 つにまとめる（1 回の取り消しで戻せるように）。変更がなければ null
function buildCommand(doc, prepared, settingsById) {
    const commands = prepared.flatMap(({ operation, state }) => operation.commands(doc, state, settingsById[operation.id])) ;
    return commands.length > 0 ? compound(commands) : null ;
}

function logSummary(prepared, settingsById) {
    const lines = prepared.map(({ operation, state }) => operation.summary(state, settingsById[operation.id])).filter((line) => line) ;
    console.log(lines.length > 0 ? `[Panel style] applied:\n${lines.join('\n')}` : '[Panel style] no change') ;
}

// ダイアログで設定する。値を変えるたびにプレビューし、OK で確定する
function runDialog(doc, model, prepared) {
    // 選択を解除しておく：選択中のオブジェクトの塗り・線をプレビューで変えると、Affinity の画面の色見本が描き直される。
    // 2026-10-19 にダイアログの試用中、色見本の描画の例外で Affinity が落ちたための予防（原因は未確定）
    doc.selection = Selection.createEmpty(doc) ;
    const dialog = Dialog.create('Panel style') ;
    dialog.initialWidth = dialogWidth ;
    dialog.isResizable = true ;

    // 左の列：図全体（全パネル共通）の項目
    const figureColumn = dialog.addColumn() ;
    for (const item of prepared.filter((entry) => entry.operation.scope === 'figure')) {
        item.controls = item.operation.addControls(figureColumn, item.state) ;
    }

    // 右の欄：パネルを選び、そのパネルの欄だけを表示する。パネルの欄は panelColumns 列に順に並べる
    const panelColumn = dialog.addColumn() ;
    const panelNames = model.panels.map((panel) => panel.panel) ;
    const selector = panelColumn.addGroup('Panels').addButtonSet('Panel', panelNames, 0) ;
    const panelItems = prepared.filter((entry) => entry.operation.scope === 'panel') ;
    for (const item of panelItems) {
        item.controls = {} ;
    }
    const panelGroups = {} ;
    for (const panel of panelNames) {
        const panelGroup = panelColumn.addGroup(`Panel ${panel}`) ;
        const stack = panelGroup.addColumnStack() ;
        const columns = Array.from({ length: panelColumns }, () => stack.addColumn()) ;
        let next = 0 ;
        const layout = {
            nextColumn() {
                const column = columns[next % panelColumns] ;
                next += 1 ;
                return column ;
            },
        } ;
        for (const item of panelItems) {
            const controls = item.operation.addPanelControls(layout, item.state, panel) ;
            if (controls) {
                item.controls[panel] = controls ;
            }
        }
        if (next === 0) {
            columns[0].addGroup('').addStaticText(null, 'No adjustable components in this panel.') ;
        }
        panelGroups[panel] = panelGroup ;
    }
    const showPanel = () => {
        const selected = panelNames[selector.selectedIndex] ;
        for (const panel of panelNames) {
            panelGroups[panel].isVisible = panel === selected ;
        }
    } ;
    selector.onValueChangedHandler = showPanel ;
    showPanel() ;

    const readAll = () => Object.fromEntries(prepared.map((item) => [item.operation.id, item.operation.readSettings(item.controls, item.state)])) ;
    const preview = () => {
        const command = buildCommand(doc, prepared, readAll()) ;
        if (command) {
            doc.executeCommand(command, true) ;
        } else {
            doc.clearPreviews() ;
        }
    } ;
    dialog.onControlValueChangedHandler = preview ;
    preview() ;
    const result = dialog.runModal() ;
    doc.clearPreviews() ;
    if (!isOk(result)) {
        return ;
    }
    const settingsById = readAll() ;
    const command = buildCommand(doc, prepared, settingsById) ;
    if (command) {
        doc.executeCommand(command) ;
    }
    logSummary(prepared, settingsById) ;
}

// MCP からの動作確認：ダイアログを出さずに、globalThis.panelStyleTest の設定を使う
// test.sequence（設定の配列）があれば、ダイアログで欄を続けて変えたときと同じく、前のプレビューを置き換えながら順にプレビューし、
// 各プレビューの後に onPreview(doc, index) を呼ぶ。'apply' では、その後で最後の設定を確定する（ダイアログの OK と同じ）
function runTest(doc, prepared, test) {
    const sequence = test.sequence ?? [test.settings ?? {}] ;
    if (test.mode === 'preview' || test.sequence) {
        sequence.forEach((settingsById, index) => {
            const command = buildCommand(doc, prepared, settingsById) ;
            if (command) {
                doc.executeCommand(command, true) ;
            } else {
                doc.clearPreviews() ;
            }
            test.onPreview?.(doc, index) ;
        }) ;
        doc.clearPreviews() ;
        console.log('[Panel style test] preview cleared') ;
        if (test.mode === 'preview') {
            return ;
        }
    }
    const settingsById = sequence[sequence.length - 1] ;
    const command = buildCommand(doc, prepared, settingsById) ;
    if (!command) {
        console.log('[Panel style test] no change') ;
        return ;
    }
    doc.executeCommand(command) ;
    logSummary(prepared, settingsById) ;
}

function main() {
    const test = globalThis.panelStyleTest ;
    // 知らせ：スクリプトパネルから実行したときは alert、MCP からの確認ではログ
    const notify = (message) => (test ? console.log(message) : alert(message)) ;
    const doc = test?.documentTitle
        ? require('/application.js').app.documents.all.find((openDoc) => openDoc.title === test.documentTitle)
        : Document.current ;
    if (!doc) {
        notify('Panel style: ドキュメントが開いていません') ;
        return ;
    }
    const spread = findPanelSpread(doc) ;
    if (!spread) {
        notify('Panel style: Panel X のレイヤーが見つかりません（affinity/compose の規則で組み立てた図を開いてください）') ;
        return ;
    }
    // 変更のコマンドは、対象のある見開きが現在の見開きでないと失敗することがあるので、切り替えておく
    if (spread.firstPageIndex !== doc.currentSpread.firstPageIndex) {
        doc.executeCommand(DocumentCommand.createSetCurrentSpread(spread)) ;
    }
    const model = scanDocument(spread) ;
    // 対象と元の値は、プレビューで変わる前に集める
    const prepared = operations
        .map((operation) => ({ operation, state: operation.prepare(doc, model) }))
        .filter((item) => item.state) ;
    if (test) {
        runTest(doc, prepared, test) ;
    } else {
        runDialog(doc, model, prepared) ;
    }
}

// ローダー（panel_style_loader.js。スクリプトパネルの「Panel style」）から読み込まれたときは、ローダーが main を呼ぶ。
// それ以外（このファイルを直接実行したとき）は、ここで実行する
if (typeof module !== 'undefined' && module.exports) {
    module.exports.main = main ;
}
if (!globalThis.panelStyleLoader) {
    main() ;
}
