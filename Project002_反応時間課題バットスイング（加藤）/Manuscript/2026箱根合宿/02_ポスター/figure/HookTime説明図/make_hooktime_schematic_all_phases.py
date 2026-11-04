# HT（フック局面）・ループ局面・加速局面の 3 つをすべて説明する版の説明図を SVG で作る（Python 3。Pillow・shapely）
#
# make_hooktime_schematic.py（ポスターの Fig.5。フック局面だけを説明する版）を写して、説明を 3 つの局面に広げたもの。
# ポスターの版はそのまま残す（2026-11-04、ユーザーの指定で別のファイルにした）。
#
# 中身：S05・Simple・Trial 12 の打者を正面から見た図（横 = X：投手方向が右、縦 = Z）。人物とバットはポスターの版と同じ。
#   - 打者：Onset（薄い灰色）とフック頂点（黒）の 2 人。手はそれぞれの時点のバットを握る（ユーザーが示したシルエットの絵から作った輪郭）
#   - 先端の軌跡：局面ごとに色を分ける（① フック局面 = HT：オレンジ、② ループ局面：空色、③ 加速局面：赤紫。
#     ②・③ の色は Okabe-Ito の色のうち、ポスターの条件の色に使っていないもの）。黒い打者の上でも見えるよう白い縁を付ける
#   - 印：○ Onset、▲ フック頂点、● ループ最深点、★ ピーク速度
#   - 右側：時点と局面の説明（30 pt、ポスターの版と同じ大きさ。時点の定義は 24 pt）。局面の時間の名前（色付き）は
#     Hook Time（HT）・Loop Time（LT）・Accel Time（AT）（ポスターの Hook Time（HT）に合わせた）、
#     時点の名前と定義は日本語（2026-11-04、ユーザーの指定）。字体はポスターの本文と同じ游ゴシック
#
# データ：s05_simple12.json（export_s05_simple12.m で x3・x5 から書き出したもの）
# 時点：x5 の TPeakVelTop から AccelTime・LoopTime・HookTime を 4 ms ずつさかのぼる（x8 の局面分けと同じ）。
#   先端の X の最大（フック頂点）・最小（ループ最深点）のフレームと一致することを確かめた（2026-11-03）
#
# 実行：python3 make_hooktime_schematic_all_phases.py（このフォルダに hooktime_schematic_all_phases.svg を書く。Pillow・shapely・PyMuPDF が要る）
# 2026-11-04

import json
import math
import os
import re
from shapely.geometry import Point, Polygon, box
from shapely.ops import unary_union
from shapely import affinity

here = os.path.dirname(os.path.abspath(__file__))
d = json.load(open(os.path.join(here, 's05_simple12.json')))

# ---- 時点（JSON の配列は 0 始まり。MATLAB のフレーム番号から 1 を引く）----
framesPerMs = d['fs']/1000
iPeak = d['tpeak'] - 1
iBack = iPeak - round(d['accel']*framesPerMs)
iHook = iBack - round(d['loop']*framesPerMs)
iOn = iHook - round(d['hook']*framesPerMs)

def m(name, i):
    return [v/1000 for v in d[name][i]]  # [m]

def xz(p):
    return (p[0], p[2])  # 正面から見た図の座標（X, Z）

def alongBat(i, s):
    """bottom から s [m] 先端側の点（X, Z）"""
    a, b = m('bottom', i), m('top', i)
    L = math.dist(a, b)
    return xz([a[j] + s*(b[j] - a[j])/L for j in range(3)])

# ---- 打者のシルエット [m] ----
# ユーザーが示したシルエットの絵をそのまま輪郭にする（2026-11-03、ユーザーの指定。絵のバットと黄色い線は除く）。
#   Onset：onset_pose_reference.png の右側の打者（両足をついて構えている）
#   フック頂点：hook_pose_reference.png の打者（前足を上げて踏み出し始めている）
# どちらも、絵の手をそれぞれの時点のバットのグリップ（bottom から 11 cm）に、足を地面（Z = 0）に合わせて、同じ縦横比で拡大する。
# データに合わせたのは手の位置だけで、体の形は絵のまま（目安）。
from PIL import Image
def tracedSilhouette(pngPath, crop, handPx, groundPx, batTipPx, batCutPx, batHalfWidthPx, gripM):
    """白黒の絵（crop の範囲）の黒い部分を輪郭にして [m] に直す。絵のバット（先端 → batCutPx の線分の周り）は除く。
    座標（handPx など）は元の絵の画素"""
    up = 4                                                        # 輪郭をなめらかにするため 4 倍に拡大してから二値化する
    im = Image.open(pngPath).convert('L').crop(crop)
    im = im.resize((im.width*up, im.height*up), Image.LANCZOS)
    w, h = im.size
    pix = im.load()
    ox, oy = crop[0], crop[1]
    (tx, ty), (cx_, cy_) = batTipPx, batCutPx
    def nearBat(x, y):                                           # バットの軸（先端 → 手の上）からの距離が半幅以内か
        X, Y = x/up + ox, y/up + oy
        vx, vy = cx_ - tx, cy_ - ty
        t = max(0.0, min(1.0, ((X - tx)*vx + (Y - ty)*vy)/(vx*vx + vy*vy)))
        return math.hypot(X - (tx + t*vx), Y - (ty + t*vy)) <= batHalfWidthPx
    rects = []
    for y in range(h):
        x = 0
        while x < w:
            if pix[x, y] < 110 and not nearBat(x, y):
                x0 = x
                while x < w and pix[x, y] < 110 and not nearBat(x, y):
                    x += 1
                rects.append(box(x0, y, x, y + 1))
            x += 1
    g = unary_union(rects)
    g = max(g.geoms, key=lambda q: q.area) if hasattr(g, 'geoms') else g     # いちばん大きなかたまり（人物）だけ
    g = Polygon(g.exterior).buffer(2*up).buffer(-2*up).simplify(0.6*up)
    s_ = (groundPx - handPx[1])/gripM[1]                          # 1 m あたりの画素
    g = affinity.translate(g, -(handPx[0] - ox)*up, -(groundPx - oy)*up)
    g = affinity.scale(g, 1/(s_*up), -1/(s_*up), origin=(0, 0))
    return affinity.translate(g, gripM[0], 0)

bodyOn = tracedSilhouette(os.path.join(here, 'onset_pose_reference.png'), crop=(320, 40, 470, 320), handPx=(361, 114), groundPx=300,
                          batTipPx=(402, 61), batCutPx=(369, 103), batHalfWidthPx=5.5, gripM=alongBat(iOn, 0.11))
bodyHook = tracedSilhouette(os.path.join(here, 'hook_pose_reference.png'), crop=(0, 0, 183, 320), handPx=(56, 90), groundPx=267,
                            batTipPx=(104, 32), batCutPx=(63, 82), batHalfWidthPx=6.5, gripM=alongBat(iHook, 0.11))

def fists(i):
    """両手：バットに沿った 1 つの塊（bottom から 5〜17 cm）"""
    return unary_union([Point(alongBat(i, 0.05)).buffer(0.045), Point(alongBat(i, 0.17)).buffer(0.045)]).convex_hull
fistsOn, fistsHook = fists(iOn), fists(iHook)

# ---- 図の大きさと縮尺 [mm] ----
# 実寸で作る（ポスターは 144 dpi なので 1 mm = 5.67 px）。説明の文字はポスターの版と同じ 30 pt、時点の定義は 24 pt
fontPt, notePt = 30, 24
fs, fsNote = fontPt*25.4/72, notePt*25.4/72   # 文字の大きさ [mm]
k = 48                 # 1 m あたりの mm
groundY = 101          # Z = 0 の位置
plotLeft = 3
allShapes = unary_union([bodyOn, bodyHook])
xs = [allShapes.bounds[0], allShapes.bounds[2]] + [m(n, i)[0] for n in ('bottom', 'top') for i in range(iOn, iPeak + 1)]
xMinM, xMaxM = min(xs) - 0.04, max(xs) + 0.04   # 描く範囲（人物とバットと軌跡が入る幅）
def px(x): return plotLeft + (x - xMinM)*k
def py(z): return groundY - z*k

phaseColour = {1: '#D55E00', 2: '#56B4E9', 3: '#CC79A7'}   # ① フック局面（HT）・② ループ局面・③ 加速局面
bodyColour = '#222222'  # フック頂点の打者とバット（Fig.1 と同じ色）
ghostColour = '#A6A6A6' # Onset の打者とバット（薄い色）
font = "font-family=\"YuGothic, Yu Gothic, Hiragino Sans, sans-serif\""   # ポスターの本文と同じ游ゴシック

svg = []
def add(s): svg.append(s)

def pathOf(geom):
    """shapely の面を SVG のパスに（穴も含める）"""
    polys = geom.geoms if hasattr(geom, 'geoms') else [geom]
    out = []
    for poly in polys:
        for ring in [poly.exterior] + list(poly.interiors):
            c = list(ring.coords)
            out.append('M ' + ' L '.join(f'{px(x):.2f},{py(z):.2f}' for x, z in c) + ' Z')
    return ' '.join(out)

# 地面と向き
plotRight = px(xMaxM)
add(f'<g id="ground"><line x1="{plotLeft:.2f}" y1="{groundY}" x2="{plotRight:.2f}" y2="{groundY}" stroke="#666" stroke-width="0.5"/>'
    f'<text x="{plotRight:.2f}" y="{groundY + 1.0*fs:.2f}" {font} font-size="{fs:.2f}" fill="#444" text-anchor="end">投手側 →</text></g>')

# 描く順番（後ろから）：Onset の打者 → Onset のバットと手 → フック頂点の打者 → フック頂点のバットと手 → 先端の軌跡 → 印
add(f'<path id="batter onset" d="{pathOf(bodyOn.simplify(0.002))}" fill="{ghostColour}" fill-rule="evenodd"/>')

# ---- バット（線ではなくバットの形）と、それを握る手（ポスターの版と同じ）----
batRadius = [(0.00, 0.019), (0.025, 0.019), (0.045, 0.012), (0.30, 0.0125), (0.45, 0.016),
             (0.62, 0.027), (0.72, 0.032), (0.97, 0.033)]   # （bottom からの割合、半径 [m]）
def batPolygon(i):
    a, b = m('bottom', i), m('top', i)
    x0, y0, x1, y1 = px(a[0]), py(a[2]), px(b[0]), py(b[2])
    L = math.hypot(x1 - x0, y1 - y0)
    ux, uy = (x1 - x0)/L, (y1 - y0)/L
    nx, ny = -uy, ux
    side1 = [(x0 + ux*f*L + nx*r*k, y0 + uy*f*L + ny*r*k) for f, r in batRadius]
    side2 = [(x0 + ux*f*L - nx*r*k, y0 + uy*f*L - ny*r*k) for f, r in batRadius]
    rEnd, fEnd = batRadius[-1][1]*k, batRadius[-1][0]
    cx, cy = x0 + ux*fEnd*L, y0 + uy*fEnd*L
    cap = [(cx + ux*rEnd*0.9*math.sin(t) + nx*rEnd*math.cos(t), cy + uy*rEnd*0.9*math.sin(t) + ny*rEnd*math.cos(t))
           for t in [j*math.pi/12 for j in range(1, 12)]]          # 先端の丸み
    knobCap = [(x0 - ux*0.004*k*math.sin(t) - nx*batRadius[0][1]*k*math.cos(t), y0 - uy*0.004*k*math.sin(t) - ny*batRadius[0][1]*k*math.cos(t))
               for t in [j*math.pi/8 for j in range(1, 8)]]        # グリップエンドの丸み
    pts = side1 + cap + side2[::-1] + knobCap
    return ' '.join(f'{x:.2f},{y:.2f}' for x, y in pts)
add('<g id="bat onset">')
add(f'<polygon points="{batPolygon(iOn)}" fill="{ghostColour}" stroke="white" stroke-width="0.4" stroke-linejoin="round"/>')
add(f'<path d="{pathOf(fistsOn)}" fill="{ghostColour}" stroke="white" stroke-width="0.35"/>')
add('</g>')
add(f'<path id="batter hook apex" d="{pathOf(bodyHook.simplify(0.002))}" fill="{bodyColour}" fill-rule="evenodd"/>')
add('<g id="bat hook apex">')
add(f'<polygon points="{batPolygon(iHook)}" fill="{bodyColour}" stroke="white" stroke-width="0.4" stroke-linejoin="round"/>')
add(f'<path d="{pathOf(fistsHook)}" fill="{bodyColour}" stroke="white" stroke-width="0.35"/>')
add('</g>')

# ---- 先端の軌跡（局面ごとの色。白い縁を下に敷く）----
phaseRanges = {1: (iOn, iHook), 2: (iHook, iBack), 3: (iBack, iPeak)}
def topPoints(i0, i1):
    return ' '.join(f'{px(m("top", i)[0]):.2f},{py(m("top", i)[2]):.2f}' for i in range(i0, i1 + 1))
add('<g id="top path">')
for ph, (i0, i1) in phaseRanges.items():
    add(f'<polyline points="{topPoints(i0, i1)}" fill="none" stroke="white" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round"/>')
for ph, (i0, i1) in phaseRanges.items():
    add(f'<polyline id="phase {ph}" points="{topPoints(i0, i1)}" fill="none" stroke="{phaseColour[ph]}" stroke-width="1.6" stroke-linejoin="round" stroke-linecap="round"/>')
add('</g>')

# ---- 4 つの時点の印 ----
def marker(kind, x, y, r=2.0):
    if kind == 'onset':
        return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="white" stroke="black" stroke-width="0.55"/>'
    if kind == 'hook':
        return (f'<polygon points="{x:.2f},{y - 1.25*r:.2f} {x + 1.1*r:.2f},{y + 0.75*r:.2f} {x - 1.1*r:.2f},{y + 0.75*r:.2f}" '
                f'fill="black" stroke="white" stroke-width="0.4"/>')
    if kind == 'back':
        return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="black" stroke="white" stroke-width="0.4"/>'
    p = []
    for j in range(10):
        rr = 1.5*r if j % 2 == 0 else 0.62*r
        t = -math.pi/2 + j*math.pi/5
        p.append(f'{x + rr*math.cos(t):.2f},{y + rr*math.sin(t):.2f}')
    return f'<polygon points="{" ".join(p)}" fill="black" stroke="white" stroke-width="0.4"/>'
add('<g id="events">')
for i, kind in [(iOn, 'onset'), (iHook, 'hook'), (iBack, 'back'), (iPeak, 'peak')]:
    b = m('top', i)
    add(marker(kind, px(b[0]), py(b[2])))
add('</g>')

# ---- 右側：時点と局面の説明（時点と局面は 30 pt、時点の定義は 24 pt）----
xLine = plotRight + 9          # 印と縦の線の位置
xText = xLine + 6
rows = [('event', 'onset', 'Onset（動作開始）'),
        ('phase', 1, 'Hook Time（HT）'),
        ('event', 'hook', 'フック頂点'), ('note', None, 'バット先端が最も投手側に出た時点'),
        ('phase', 2, 'Loop Time（LT）'),
        ('event', 'back', 'ループ最深点'), ('note', None, 'バット先端が最も捕手側に来た時点'),
        ('phase', 3, 'Accel Time（AT）'),
        ('event', 'peak', 'ピーク速度'), ('note', None, 'バット先端の合成速度が最大の時点')]
gapAfter = {'event': 1.25*fs, 'phase': 1.25*fs, 'note': 1.0*fsNote + 0.6*fs}
baselines = []
y = 4 + fs
for kind, key, label in rows:
    if kind == 'note':
        y = baselines[-1] + 1.15*fsNote   # 時点の名前のすぐ下
    baselines.append(y)
    y = y + gapAfter[kind]
markerY = lambda j: baselines[j] - 0.36*fs
eventRows = [j for j, r in enumerate(rows) if r[0] == 'event']
add('<g id="legend">')
for ph in (1, 2, 3):
    add(f'<line x1="{xLine:.2f}" y1="{markerY(eventRows[ph - 1]):.2f}" x2="{xLine:.2f}" y2="{markerY(eventRows[ph]):.2f}" stroke="{phaseColour[ph]}" stroke-width="2.2"/>')
for j, (kind, key, label) in enumerate(rows):
    if kind == 'event':
        add(marker(key, xLine, markerY(j), r=2.6))
        add(f'<text x="{xText:.2f}" y="{baselines[j]:.2f}" {font} font-size="{fs:.2f}" font-weight="700">{label}</text>')
    elif kind == 'phase':
        add(f'<text x="{xText:.2f}" y="{baselines[j]:.2f}" {font} font-size="{fs:.2f}" font-weight="700" fill="{phaseColour[key]}">{label}</text>')
    else:
        add(f'<text x="{xText:.2f}" y="{baselines[j]:.2f}" {font} font-size="{fsNote:.2f}" fill="#333">{label}</text>')
add('</g>')

# 図全体の大きさ：文字の幅は、全角 1 字 = 1 em、半角 1 字 = 0.56 em で見積もる（Arial の平均の幅）
def textWidth(t, size):
    return sum(size if ord(c) > 0x2000 else 0.56*size for c in t)
W = math.ceil(xText + max(textWidth(r[2], fsNote if r[0] == 'note' else fs) for r in rows) + 2)
H = math.ceil(max(baselines[-1] + 0.3*fs, groundY + 1.0*fs + 0.3*fs))

with open(os.path.join(here, 'hooktime_schematic_all_phases.svg'), 'w') as f:
    f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}mm" height="{H}mm" viewBox="0 0 {W} {H}">\n')
    f.write('\n'.join(svg))
    f.write('\n</svg>\n')

# 図の幅：文字の幅の見積もり（全角 1 em）と、描かれた範囲の右端 + 3 mm（PyMuPDF で描画して測る）の大きいほう。
# 英語は見積もりが広めになるので描画で詰め、日本語は描画の字体（代わりの字体）より游ゴシックが広いことがあるので見積もりを使う
import fitz
svgPath = os.path.join(here, 'hooktime_schematic_all_phases.svg')
page = fitz.open(svgPath)[0]
pix = page.get_pixmap(matrix=fitz.Matrix(4, 4), alpha=True)
cols = [x for x in range(pix.width) if any(pix.pixel(x, y)[3] > 0 for y in range(0, pix.height, 3))]
inkRightMm = max(cols)/pix.width*W
W2 = max(math.ceil(inkRightMm + 3), math.ceil(xText + max(textWidth(r[2], fsNote if r[0] == 'note' else fs) for r in rows if not r[2].isascii()) + 3))
text = open(svgPath).read().replace(f'width="{W}mm" height="{H}mm" viewBox="0 0 {W} {H}"', f'width="{W2}mm" height="{H}mm" viewBox="0 0 {W2} {H}"', 1)
open(svgPath, 'w').write(text)
W = W2

print('frames', iOn, iHook, iBack, iPeak, 'plotRight', round(plotRight, 1), 'size', W, H, 'mm')
