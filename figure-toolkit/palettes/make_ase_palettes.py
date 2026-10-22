"""論文・ポスターで使うパレットを、Affinity のスウォッチに読み込める Adobe Swatch Exchange（.ase）ファイルにする（2026-10-19）。

Panel style（affinity/panel-tools/panel_style_tool.js）の色の欄は Affinity の色の欄なので、ここで作ったパレットを
スウォッチに読み込んでおくと、色の欄のスウォッチから選べる。
各パレットについて、色ごとに 黒寄り 60・80 %（残りは黒）、100 %、白寄り 80・60・40・20 %（残りは白）の見本を並べ、
最後に灰色の段階（Grey と同じもの）を加えた 1 つの .ase を書き出す。Grey は灰色の段階だけ。
出力：figure-toolkit/palettes/<パレット名>.ase
実行（figure-toolkit のフォルダで）：python palettes/make_ase_palettes.py
Affinity への読み込み：スウォッチパネルのメニュー（≡）から パレットを読み込み > アプリケーションパレットとして（2026-10-19 に確認）。
作り直したパレットは、読み込み済みの同じ名前のパレットを削除してから読み込み直す。
"""
import struct
from pathlib import Path

# パレット（値は 0〜255 の RGB）：Okabe & Ito (2008)、Paul Tol の bright・muted、広島大学（ポスター用）
palettes = [
    ('Okabe-Ito', [
        ('black', 0, 0, 0), ('orange', 230, 159, 0), ('sky blue', 86, 180, 233), ('bluish green', 0, 158, 115),
        ('yellow', 240, 228, 66), ('blue', 0, 114, 178), ('vermilion', 213, 94, 0), ('reddish purple', 204, 121, 167)]),
    ('Tol bright', [
        ('blue', 68, 119, 170), ('cyan', 102, 204, 238), ('green', 34, 136, 51), ('yellow', 204, 187, 68),
        ('red', 238, 102, 119), ('purple', 170, 51, 119), ('grey', 187, 187, 187)]),
    ('Tol muted', [
        ('indigo', 51, 34, 136), ('cyan', 136, 204, 238), ('teal', 68, 170, 153), ('green', 17, 119, 51), ('olive', 153, 153, 51),
        ('sand', 221, 204, 119), ('rose', 204, 102, 119), ('wine', 136, 34, 85), ('purple', 170, 68, 153)]),
    # 広島大学：学章の指定色（グリーン・ゴールド・シルバー）と大学名ロゴタイプの広大ブラック
    #   出典：広島大学 学章・ロゴタイプ デザインマニュアル（2024 年 12 月版）
    #   https://www.hiroshima-u.ac.jp/system/files/250483/hiroshimauniv_manual202412.pdf
    #   グリーン DIC 379（C100 M60 Y100、R0 G94 B60）、ゴールド DIC 798（M30 Y100 K10、R234 G179 B0）、
    #   シルバー DIC 946（K20、R220 G221 B221）、広大ブラック DIC 582（K100。RGB の記載はないので 0, 0, 0 とする）
    # 後半の 4 色は、指定色と合わせて使うために選んだ色（大学の指定色ではない）：
    #   navy・sky blue（グリーンと同じ寒色の系統で、グリーンと区別できる青）、leaf green（グリーンの明るい色）、
    #   vermilion（グリーンの反対色相の側にあり、ゴールドとも合う強調の色）
    ('Hiroshima Univ', [
        ('green', 0, 94, 60), ('gold', 234, 179, 0), ('silver', 220, 221, 221), ('black', 0, 0, 0),
        ('navy', 0, 64, 112), ('sky blue', 64, 160, 210), ('leaf green', 120, 180, 60), ('vermilion', 200, 80, 40)]),
]
dark_shades = [60, 80]  # 色の割合 [%]（残りは黒）
light_shades = [100, 80, 60, 40, 20]  # 色の割合 [%]（残りは白）
# 灰色の段階：黒の割合 [%]。15 % は MATLAB の信頼区間の帯（217）、40・60 % はイベント線（102）・参加者の線（153）の既定の色
grey_levels = [100, 90, 80, 70, 60, 50, 40, 30, 20, 15, 10, 0]
output_dir = Path(__file__).resolve().parent


def tint(rgb, percent):
    """色の割合 percent [%]（残りは白）の色。panel_style_tool.js の tint と同じ計算"""
    return tuple(round(c*percent/100 + 255*(1 - percent/100)) for c in rgb)


def shade(rgb, percent):
    """色の割合 percent [%]（残りは黒）の色"""
    return tuple(round(c*percent/100) for c in rgb)


def grey_name(level):
    return {100: 'black', 0: 'white'}.get(level, f'grey {level}%')


def name_field(name):
    """ASE の名前：長さ（終端の 0 を含む文字数）と UTF-16BE の文字列"""
    encoded = (name + '\0').encode('utf-16-be')
    return struct.pack('>H', len(encoded)//2) + encoded


def colour_block(name, rgb):
    body = name_field(name) + b'RGB ' + struct.pack('>3f', *(c/255 for c in rgb)) + struct.pack('>H', 2)  # 2 = 通常の色
    return struct.pack('>HI', 0x0001, len(body)) + body


def group_start(name):
    body = name_field(name)
    return struct.pack('>HI', 0xC001, len(body)) + body


def group_end():
    return struct.pack('>HI', 0xC002, 0)


def grey_blocks(palette_name, has_black=False):
    """灰色の段階。パレットに黒があるときは、段階の黒を省く（同じ名前の見本が 2 つにならないように）"""
    levels = [level for level in grey_levels if not (has_black and level == 100)]
    return [colour_block(f'{palette_name} {grey_name(level)}', (round(255*(1 - level/100)),)*3) for level in levels]


def write_palette(palette_name, blocks):
    blocks = [group_start(palette_name)] + blocks + [group_end()]
    data = b'ASEF' + struct.pack('>HHI', 1, 0, len(blocks)) + b''.join(blocks)
    path = output_dir / f"{palette_name.replace(' ', '_')}.ase"
    path.write_bytes(data)
    return path


for palette_name, colours in palettes:
    blocks = []
    for colour_name, r, g, b in colours:
        if (r, g, b) == (0, 0, 0):  # 黒の段階は灰色の段階と同じなので、黒は 1 つだけ
            blocks.append(colour_block(f'{palette_name} {colour_name}', (0, 0, 0)))
            continue
        for percent in dark_shades:
            blocks.append(colour_block(f'{palette_name} {colour_name} {percent}% dark', shade((r, g, b), percent)))
        for percent in light_shades:
            blocks.append(colour_block(f'{palette_name} {colour_name} {percent}%', tint((r, g, b), percent)))
    greys = grey_blocks(palette_name, has_black=any((r, g, b) == (0, 0, 0) for _, r, g, b in colours))
    blocks += greys
    path = write_palette(palette_name, blocks)
    print(f'{path.name}: {len(colours)} colours, {len(blocks) - len(greys)} colour swatches + {len(greys)} greys')
path = write_palette('Grey', grey_blocks('Grey'))
print(f'{path.name}: {len(grey_levels)} greys')
