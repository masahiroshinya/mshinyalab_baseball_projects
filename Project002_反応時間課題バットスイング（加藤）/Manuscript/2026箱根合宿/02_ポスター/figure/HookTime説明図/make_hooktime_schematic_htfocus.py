# 全局面の説明図（hooktime_schematic_all_phases.svg）から、HT を目立たせた版を作る（2026-11-05、ショートトークの 9 枚目用）
#   LT・AT は色の代わりに灰色（薄くはしない。不透明度を下げた版はわかりづらいとのユーザーの指摘）。HT を強調する：
#   - 先端の軌跡：HT（フック局面）を太く（1.6 → 3.2）し、下に薄いオレンジの光（太さ 8、不透明度 0.3）を敷く
#   - 右の説明：Onset〜フック頂点の定義までの行に白い背景（細いオレンジの縁）、HT の縦の線を太く（2.2 → 3.6）、「Hook Time（HT）」の文字を 1.25 倍
# 元の図は make_hooktime_schematic_all_phases.py で作る（このスクリプトはその出力を書き換えるだけ）
# 実行：python3 make_hooktime_schematic_htfocus.py（このフォルダに hooktime_schematic_all_phases_htfocus.svg を書く）
import copy
import os
import xml.etree.ElementTree as ET

here = os.path.dirname(os.path.abspath(__file__))
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)
tree = ET.parse(os.path.join(here, 'hooktime_schematic_all_phases.svg'))
root = tree.getroot()
q = lambda t: f'{{{NS}}}{t}'
W = float(root.get('viewBox').split()[2])
HT = '#D55E00'
g = {e.get('id'): e for e in root.iter(q('g')) if e.get('id')}

# 先端の軌跡：白い縁 3 本 → 色の線 3 本の順。HT（1 本目）を太くし、光を一番下に敷く
lines = list(g['top path'].iter(q('polyline')))
glow = copy.deepcopy(lines[3])
glow.attrib.pop('id', None)
glow.set('stroke-width', '8'); glow.set('opacity', '0.3')
g['top path'].insert(0, glow)
lines[0].set('stroke-width', '4.4'); lines[3].set('stroke-width', '3.2')

# 右の説明
legend = g['legend']
yTop, yBottom, xLeft = 3.5, 54.0, 73.0     # Onset の行の上 〜 フック頂点の定義の行の下（mm）
band = ET.Element(q('rect'), {'x': f'{xLeft}', 'y': f'{yTop}', 'width': f'{W - xLeft - 0.5:.2f}', 'height': f'{yBottom - yTop}',
                              'rx': '3', 'fill': 'white', 'fill-opacity': '0.75', 'stroke': HT, 'stroke-width': '0.6'})   # スライドの薄緑の枠の上で濁らないよう白
legend.insert(0, band)
for e in legend:
    if e.tag == q('line') and e.get('stroke') == HT:
        e.set('stroke-width', '3.6')
    if e.tag == q('text') and (e.text or '').startswith('Hook Time'):
        e.set('font-size', f'{1.25*float(e.get("font-size")):.2f}')
# LT・AT は色の代わりに灰色にする（2026-11-05、ユーザーの指定。軌跡・縦の線・局面の名前。時点の名前と定義は元のまま）
GRAY, GRAY_TEXT = '#A6A6A6', '#8C8C8C'
for e in root.iter():
    if e.get('stroke') in ('#56B4E9', '#CC79A7'):
        e.set('stroke', GRAY)
    if e.tag == q('text') and e.get('fill') in ('#56B4E9', '#CC79A7'):
        e.set('fill', GRAY_TEXT)
# ループ最深点・ピーク速度（名前・定義・印）も灰色にする（2026-11-05、ユーザーの指定）。右の説明でフック頂点の定義より下の行と、打者の絵の 3・4 番目の印
def yOf(e):
    if e.tag == q('text'): return float(e.get('y'))
    if e.tag == q('circle'): return float(e.get('cy'))
    if e.tag == q('polygon'):
        p = e.get('points').split(); return sum(float(v.split(',')[1]) for v in p)/len(p)
    return 0
for e in legend:
    if e.tag in (q('text'), q('circle'), q('polygon')) and yOf(e) > yBottom:
        e.set('fill', GRAY_TEXT if e.tag == q('text') else GRAY)
for e in list(g['events'])[2:]:
    e.set('fill', GRAY)
tree.write(os.path.join(here, 'hooktime_schematic_all_phases_htfocus.svg'), encoding='utf-8', xml_declaration=False)
print('ok')
