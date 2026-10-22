"""スクリプトパネル（affinity/panel-tools/panel_style_tool.js）の試験用に、A〜D の 4 パネルからなる図の素材を作る（2026-10-19、試験用）。

原案から作る複数パネルの図には使わない（入力が input/panels/ に固定されている）。その場合は AGENTS.md の 4 節の 6 の手順
（examples/draft_figures_2x2/combine_draft_figures_2x2.py を写して使う）による。

単一パネルの 4 図（figure-types/make_all_examples.m の出力）の成分ごとのページの PDF を 1 つにまとめ、パネル記号を A〜D に付け替えた
構成の JSON（図全体の JSON）を書き出す。Affinity ではファイル間でオブジェクトを移せないため、全パネルのページを 1 つの PDF に入れる。
並べ方：2 × 2（double column 190 mm × 高さ 120 mm）。各パネルは 8 × 6 cm のまま（幅の割り振りの方針は未決定のため、試験用の仮の配置）。
入力：デスクトップの affinity_mcp_work/input/panels/（<name>_components.pdf、<name>.json）
出力：デスクトップの affinity_mcp_work/input/test_figures/（test_figure_4panels_components.pdf、test_figure_4panels.json）
実行（figure-toolkit のフォルダで）：python tools/make_test_figure_4panels.py（先に figure-types/make_all_examples.m を実行しておく）
組み立て：python tools/stack_component_pages.py test_figures/test_figure_4panels.json の後、
      AFFINITY_COLLECT_DIR=<移す先の絶対パス> node tools/affinity-mcp.mjs run affinity/compose/compose_test_figure.js
"""
import json
import os
from pathlib import Path

from pypdf import PdfReader, PdfWriter

# 作業フォルダ：環境変数 AFFINITY_WORK_DIR があればそれを使う（tools/affinity-mcp.mjs、matlab/toolkitPaths.m と同じ）
work_dir = Path(os.environ.get('AFFINITY_WORK_DIR') or Path.home() / 'Desktop' / 'affinity_mcp_work') / 'input'
source_dir = work_dir / 'panels'
output_dir = work_dir / 'test_figures'
figure_name = 'test_figure_4panels'

# パネルの割り当てと、図の中での左上の位置 [mm]（上の行：時系列、下の行：棒グラフと散布図）
panel_layout = [
    ('A', 'kinematic_sequence', [0, 0]),
    ('B', 'running_grf', [95, 0]),
    ('C', 'jump_height', [0, 60]),
    ('D', 'ball_speed_scatter', [95, 60]),
]
figure_area = {'column': 'double', 'widthMm': 190, 'heightMm': 120}

output_dir.mkdir(parents=True, exist_ok=True)
writer = PdfWriter()
panels = []
page_offset = 0  # それまでに追加したページ数
for letter, name, offset_mm in panel_layout:
    spec = json.loads((source_dir / f'{name}.json').read_text(encoding='utf-8'))
    reader = PdfReader(source_dir / spec['componentsPdf'])
    for page in reader.pages:
        writer.add_page(page)

    # パネル記号の付け替え（サブレイヤー名の接頭辞）と、まとめた PDF でのページ番号への付け替え
    old_prefix = f"{spec['panel']}: "
    for page in spec['pages']:
        page['page'] += page_offset
        for layer in page['layers']:
            if layer['name'].startswith(old_prefix):
                layer['name'] = f'{letter}: ' + layer['name'][len(old_prefix):]
    spec['calibration']['page'] += page_offset
    spec['referencePage'] = page_offset + 1  # 比較用の全体図のページ（各図の 1 ページ目）
    spec['panel'] = letter
    spec['offsetMm'] = offset_mm
    spec.pop('componentsPdf', None)
    spec.pop('figureArea', None)
    panels.append(spec)
    print(f'{letter}: {name}, pages {page_offset + 1}-{page_offset + len(reader.pages)}, offset {offset_mm} mm')
    page_offset += len(reader.pages)

components_pdf = f'{figure_name}_components.pdf'
with open(output_dir / components_pdf, 'wb') as file:
    writer.write(file)
figure_spec = {
    'name': figure_name,
    'componentsPdf': components_pdf,
    'figureArea': figure_area,
    'panels': panels,
}
(output_dir / f'{figure_name}.json').write_text(json.dumps(figure_spec, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'wrote {output_dir / components_pdf} ({page_offset} pages) and {figure_name}.json')
