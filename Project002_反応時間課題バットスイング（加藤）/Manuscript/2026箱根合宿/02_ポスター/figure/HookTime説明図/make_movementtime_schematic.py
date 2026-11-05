# MT（Movement Time：動作時間）の説明図を SVG で作る（Python 3。絵を輪郭にするのに Pillow と shapely を使う）
# make_hooktime_schematic.py（HT の説明図）を写して、説明を Onset からピーク速度まで（MT）に替えたもの（2026-11-05、ショートトーク用）
#
# 中身：S05・Simple・Trial 12 の打者を正面から見た図（横 = X：投手方向が右、縦 = Z）。人物とバットは HT の説明図と同じ。
#   - 打者：Onset の姿勢（薄い灰色）と、スイング中の姿勢（黒。HT の説明図のフック頂点と同じ。ピーク速度の姿勢の絵はないので、説明は付けない）
#   - バット：Onset（薄い灰色）とフック頂点（黒）
#   - 太い線：Onset からピーク速度までの先端の軌跡（MT の色。黒い打者の上でも見えるよう白い縁を付ける。make_hooktime_schematic_all_phases.py と同じ）
#   - 印：○ Onset、★ ピーク速度
#   - 右側：Onset・動作時間（Movement Time）・ピーク速度の説明
#
# シルエット：ユーザーが示したシルエットの絵（onset_pose_reference.png・hook_pose_reference.png）をそのまま輪郭にする（2026-11-03）。
#   手をデータのバットのグリップに、足を地面に合わせる。詳しくは「打者のシルエット」の段落
#
# データ：s05_simple12.json（export_s05_simple12.m で x3・x5 から書き出したもの）
# 時点：x5 の TPeakVelTop から AccelTime・LoopTime・HookTime を 4 ms ずつさかのぼる（x8 の局面分けと同じ）。
#   先端の X の最大（フック頂点）・最小（ループ最深点）のフレームと一致することを確かめた（2026-11-03）
#
# 実行：python3 make_movementtime_schematic.py（このフォルダに movementtime_schematic.svg を書く。Pillow と shapely が要る）
# 2026-11-05

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
# ポスターに置く実寸で作る（Affinity で拡大・縮小しない。ポスターは 144 dpi なので 1 mm = 5.67 px）。
# 説明の文字はポスター上で 30 pt（2026-11-03、ユーザーの指定）
fontPt = 30
fs = fontPt*25.4/72    # 文字の大きさ [mm]
lineGap = 1.25*fs      # 行の間隔 [mm]
k = 42                 # 1 m あたりの mm
groundY = 88           # Z = 0 の位置
plotLeft = 3
allShapes = unary_union([bodyOn, bodyHook])
xs = [allShapes.bounds[0], allShapes.bounds[2]] + [m(n, i)[0] for n in ('bottom', 'top') for i in range(iOn, iPeak + 1)]
xMinM, xMaxM = min(xs) - 0.04, max(xs) + 0.04   # 描く範囲（人物とバットが入る幅）
def px(x): return plotLeft + (x - xMinM)*k
def py(z): return groundY - z*k

mtColour = '#0072B2'    # MT（Okabe-Ito の青。HT・LT・AT の色と重ならない）
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

# 地面と向き（30 pt では「← 捕手側」と「投手側 →」が並ばないので、投手側だけ書く）
plotRight = px(xMaxM)
add(f'<g id="ground"><line x1="{plotLeft:.2f}" y1="{groundY}" x2="{plotRight:.2f}" y2="{groundY}" stroke="#666" stroke-width="0.5"/>'
    f'<text x="{plotRight:.2f}" y="{groundY + 1.0*fs:.2f}" {font} font-size="{fs:.2f}" fill="#444" text-anchor="end">投手側 →</text></g>')

# 描く順番（後ろから）：Onset の打者 → Onset のバットと手 → フック頂点の打者 → フック頂点のバットと手 → 先端の軌跡 → 印
# Onset の打者
add(f'<path id="batter onset" d="{pathOf(bodyOn.simplify(0.002))}" fill="{ghostColour}" fill-rule="evenodd"/>')


# ---- バット（線ではなくバットの形）と、それを握る手 ----
# 握り側の端（bottom）から先端（top）までの、データの 2 点を結ぶ軸に沿って、標準的な木製バットの太さ（半径）を付ける。
# 長さは画面に写した長さ（bottom → top）、太さは実寸（画面の奥行きの影響を受けない）
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
# フック頂点の打者（Onset のバットと手より前）
add(f'<path id="batter hook apex" d="{pathOf(bodyHook.simplify(0.002))}" fill="{bodyColour}" fill-rule="evenodd"/>')
add('<g id="bat hook apex">')
add(f'<polygon points="{batPolygon(iHook)}" fill="{bodyColour}" stroke="white" stroke-width="0.4" stroke-linejoin="round"/>')
add(f'<path d="{pathOf(fistsHook)}" fill="{bodyColour}" stroke="white" stroke-width="0.35"/>')
add('</g>')

# Onset からピーク速度までの先端の軌跡（バットの上に重ねる。白い縁を下に敷く）
pts = ' '.join(f'{px(m("top", i)[0]):.2f},{py(m("top", i)[2]):.2f}' for i in range(iOn, iPeak + 1))
add('<g id="top path">')
add(f'<polyline points="{pts}" fill="none" stroke="white" stroke-width="2.8" stroke-linejoin="round" stroke-linecap="round"/>')
add(f'<polyline id="top path MT" points="{pts}" fill="none" stroke="{mtColour}" stroke-width="1.8" stroke-linejoin="round" stroke-linecap="round"/>')
add('</g>')

# Onset とピーク速度の印（名前は右の説明に書く。★ は make_hooktime_schematic_all_phases.py と同じ形）
def marker(kind, x, y, r=2.0):
    if kind == 'onset':
        return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{r:.2f}" fill="white" stroke="black" stroke-width="0.55"/>'
    p = []
    for j in range(10):
        rr = 1.5*r if j % 2 == 0 else 0.62*r
        t = -math.pi/2 + j*math.pi/5
        p.append(f'{x + rr*math.cos(t):.2f},{y + rr*math.sin(t):.2f}')
    return f'<polygon points="{" ".join(p)}" fill="black" stroke="white" stroke-width="0.4"/>'

add('<g id="events">')
for i, kind in [(iOn, 'onset'), (iPeak, 'peak')]:
    b = m('top', i)
    add(marker(kind, px(b[0]), py(b[2])))
add('</g>')

# ---- 右側：時点と局面の説明（30 pt。1 行ずつ）----
xLine = plotRight + 9          # 印と縦の線の位置
xText = xLine + 6
rows = [('onset', 'Onset（動作開始）', 'bold'),
        ('', '動作時間', 'phase'), ('', '＝ Movement Time（MT）', 'phase'),
        ('peak', 'ピーク速度', 'bold'), ('', 'バット先端の合成速度が', 'note'), ('', '最大の時点', 'note'),
        ('', 'MT = t_peak − t_onset', 'eq')]          # 算出式（ポスターの Eq.6 と同じ。2026-11-05、ユーザーの指定で説明文の下に）
firstBaseline = 4 + fs
baselines = [firstBaseline + j*lineGap for j in range(len(rows))]
# 式の行は説明文と分けるため、上の行との間を 0.35 字分広げる
jEq = [j for j, r in enumerate(rows) if r[2] == 'eq'][0]
eqFs = 1.3*fs   # 式だけ大きくする（2026-11-05、ユーザーの指定）
baselines = [b + (0.35*fs + 0.8*(eqFs - fs) if j >= jEq else 0) for j, b in enumerate(baselines)]
markerY = lambda j: baselines[j] - 0.36*fs
add('<g id="legend">')
add(f'<line x1="{xLine:.2f}" y1="{markerY(0):.2f}" x2="{xLine:.2f}" y2="{markerY(3):.2f}" stroke="{mtColour}" stroke-width="2.2"/>')
for j, (mk, textValue, style) in enumerate(rows):
    if mk:
        add(marker(mk, xLine, markerY(j), r=2.6))
    if style == 'eq':  # 数式の書体：変数は斜体、下付きの peak・onset は立体（LaTeX の t_{\mathrm{peak}} と同じ）
        mf = 'font-family="Cambria Math, STIX Two Math, Times New Roman, serif"'
        sub = lambda t: f'<tspan font-style="normal" font-size="{0.7*eqFs:.2f}" dy="{0.22*eqFs:.2f}">{t}</tspan>'
        back = f'<tspan dy="{-0.22*eqFs:.2f}"> </tspan>'
        add(f'<text x="{xText:.2f}" y="{baselines[j]:.2f}" {mf} font-size="{eqFs:.2f}" font-style="italic" xml:space="preserve">'
            f'MT<tspan font-style="normal">\u2005=\u2005</tspan>t{sub("peak")}{back}<tspan font-style="normal">−\u2005</tspan>t{sub("onset")}</text>')
        # 空白は U+2005（4 分の 1 字）：PowerPoint の SVG の表示は普通の空白を詰めるため
        continue
    attrs = {'bold': 'font-weight="700"', 'note': 'fill="#333"', 'phase': f'font-weight="700" fill="{mtColour}"'}[style]
    add(f'<text x="{xText:.2f}" y="{baselines[j]:.2f}" {font} font-size="{fs:.2f}" {attrs}>{textValue}</text>')
add('</g>')

# 図全体の大きさ：文字の幅は、全角 1 字 = 1 em、半角 1 字 = 0.6 em で見積もる
def textWidth(t):
    return sum(fs if ord(c) > 0x2000 else 0.6*fs for c in t)
W = math.ceil(xText + max(textWidth(r[1]) for r in rows) + 2)
H = math.ceil(max(baselines[-1] + 0.6*eqFs, groundY + 1.0*fs + 0.3*fs))   # 式の下付きの分を見込む

with open(os.path.join(here, 'movementtime_schematic.svg'), 'w') as f:
    f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}mm" height="{H}mm" viewBox="0 0 {W} {H}">\n')
    f.write('\n'.join(svg))
    f.write('\n</svg>\n')

print('frames', iOn, iHook, iBack, iPeak, 'plotRight', round(plotRight, 1), 'size', W, H, 'mm')
