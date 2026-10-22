"""draft_figures_2x2_revised の 4 パネル（make_draft_figures_2x2_revised.m の出力）を、Affinity で組み立てる 1 つの図の素材にまとめる。

tools/make_test_figure_4panels.py（試験用の 4 パネルの図）と同じ処理を、この図のパネルと配置で行う。
Affinity ではファイル間でオブジェクトを移せないため、全パネルの成分のページを 1 つの PDF に入れ、ページ番号を付け替えた構成の JSON を書く。
配置（各パネルの左上の位置、図全体の大きさ）は、make_draft_figures_2x2_revised.m が書き出した draft_figures_2x2_revised_layout.json から読む
（パネルの大きさと配置を MATLAB のスクリプトの 1 か所で決めるため）。
入力：デスクトップの affinity_mcp_work/input/draft_figures_2x2_revised/（<パネル>_components.pdf、<パネル>.json、draft_figures_2x2_revised_layout.json）
出力：デスクトップの affinity_mcp_work/input/test_figures/（draft_figures_2x2_revised_components.pdf、draft_figures_2x2_revised.json）。
      affinity/compose/compose_test_figure.js が読む場所なので、そこに置く。続けて tools/stack_component_pages.py で 1 ページに並べる
実行（figure-toolkit のフォルダで）：python examples/draft_figures_2x2_revised/combine_draft_figures_2x2_revised.py（先に make_draft_figures_2x2_revised.m を実行しておく）
"""
import json
import os
from pathlib import Path

from pypdf import PdfReader, PdfWriter

# 作業フォルダ：環境変数 AFFINITY_WORK_DIR があればそれを使う（tools/affinity-mcp.mjs、matlab/toolkitPaths.m と同じ）
figure_name = 'draft_figures_2x2_revised'
input_dir = Path(os.environ.get('AFFINITY_WORK_DIR') or Path.home() / 'Desktop' / 'affinity_mcp_work') / 'input'
source_dir = input_dir / figure_name
output_dir = input_dir / 'test_figures'

layout = json.loads((source_dir / f'{figure_name}_layout.json').read_text(encoding='utf-8'))

output_dir.mkdir(parents=True, exist_ok=True)
writer = PdfWriter()
panels = []
page_offset = 0  # それまでに追加したページ数
for placement in layout['panels']:
    letter = placement['panel']
    spec = json.loads((source_dir / f"{placement['source']}.json").read_text(encoding='utf-8'))
    if spec['panel'] != letter:
        raise ValueError(f"{placement['source']}: パネル記号が {spec['panel']}（配置では {letter}）")
    reader = PdfReader(source_dir / spec['componentsPdf'])
    for page in reader.pages:
        writer.add_page(page)

    # まとめた PDF でのページ番号への付け替え（サブレイヤー名の接頭辞は MATLAB で A〜D にしてあるので変えない）
    for page in spec['pages']:
        page['page'] += page_offset
    spec['calibration']['page'] += page_offset
    spec['referencePage'] = page_offset + 1  # 比較用の全体図のページ（各パネルの 1 ページ目）
    spec['offsetMm'] = placement['offsetMm']
    spec.pop('componentsPdf', None)
    spec.pop('figureArea', None)
    panels.append(spec)
    print(f"{letter}: {placement['source']}, pages {page_offset + 1}-{page_offset + len(reader.pages)}, offset {placement['offsetMm']} mm")
    page_offset += len(reader.pages)

components_pdf = f'{figure_name}_components.pdf'
with open(output_dir / components_pdf, 'wb') as file:
    writer.write(file)
figure_spec = {
    'name': figure_name,
    'componentsPdf': components_pdf,
    'figureArea': layout['figureArea'],
    'panels': panels,
}
(output_dir / f'{figure_name}.json').write_text(json.dumps(figure_spec, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'wrote {output_dir / components_pdf} ({page_offset} pages) and {figure_name}.json')
