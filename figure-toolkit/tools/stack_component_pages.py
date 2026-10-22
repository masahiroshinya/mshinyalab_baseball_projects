"""成分ごとのページの PDF を、1 ページに並べた PDF にする（Affinity の .af に空のページを残さないため。2026-10-19）。

Affinity の SDK ではページ（見開き）を削除できないので、複数ページの PDF を開いて組み立てると、2 ページ目以降が空のページとして残る。
そこで、組み立ての前に、全ページを 1 ページの上に格子状に並べた PDF を作る。組み立てのスクリプト（affinity/compose/）は、
ページごとの領域にある要素を元のページの位置へ戻してから、これまでと同じ手順で組み立てる。

入力：exportPanel が書いた単一パネルの JSON、または複数パネルの図の JSON（どちらも componentsPdf を持つ）。フォルダを指定すると、
      その中の componentsPdf を持つすべての JSON を処理する。
出力：<成分の PDF の名前>_stacked.pdf（同じフォルダ）。JSON に次を加える（組み立てのスクリプトが読む）：
      stackedPdf    1 ページに並べた PDF のファイル名
      stackedPages  columns（列の数）、gapPt（ページの間隔）、cellSizePt（1 つのページの枠の幅と高さ）、
                    offsetsPt（元のページごとの、並べた PDF の左上からの位置 [x, y]。y は下向き）[pt]
MATLAB で書き出し直すと JSON が上書きされて stackedPdf がなくなるので、そのたびに実行する（ないときは、組み立てのスクリプトは
複数ページの PDF をそのまま使い、空のページが残る）。
実行（figure-toolkit のフォルダで）：python tools/stack_component_pages.py <JSON またはフォルダ> [...]
      見つからない場所は、作業フォルダの input/ からの相対として探す（例：panels、test_figures/test_figure_4panels.json）。
      作業フォルダは、環境変数 AFFINITY_WORK_DIR、なければデスクトップの affinity_mcp_work。
"""
import json
import math
import os
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter, Transformation

work_input_dir = Path(os.environ.get('AFFINITY_WORK_DIR') or Path.home() / 'Desktop' / 'affinity_mcp_work') / 'input'
gap_pt = 36.0  # ページの間隔 [pt]（12.7 mm。ページの外にはみ出した要素が隣のページの領域に入らないように）


def stack_pages(json_path):
    """JSON の componentsPdf を 1 ページに並べ、JSON に stackedPdf と stackedPages を加える"""
    spec = json.loads(json_path.read_text(encoding='utf-8'))
    if 'componentsPdf' not in spec:
        return False
    components_path = json_path.parent / spec['componentsPdf']
    reader = PdfReader(components_path)
    pages = reader.pages
    n_pages = len(pages)
    cell_width = max(float(page.mediabox.width) for page in pages)
    cell_height = max(float(page.mediabox.height) for page in pages)
    columns = math.ceil(math.sqrt(n_pages))
    rows = math.ceil(n_pages/columns)
    total_width = columns*cell_width + (columns - 1)*gap_pt
    total_height = rows*cell_height + (rows - 1)*gap_pt

    writer = PdfWriter()
    target = writer.add_blank_page(width=total_width, height=total_height)
    offsets = []
    for index, page in enumerate(pages):
        left = (index % columns)*(cell_width + gap_pt)  # 並べた PDF の左上からの位置 [pt]
        top = (index//columns)*(cell_height + gap_pt)
        # PDF の座標は左下が原点で上向きなので、元のページの左上が (left, top) に来るように平行移動する
        box = page.mediabox
        translate_x = left - float(box.left)
        translate_y = total_height - top - float(box.height) - float(box.bottom)
        target.merge_transformed_page(page, Transformation().translate(translate_x, translate_y))
        offsets.append([round(left, 4), round(top, 4)])

    stacked_name = f"{Path(spec['componentsPdf']).stem}_stacked.pdf"
    with open(json_path.parent / stacked_name, 'wb') as file:
        writer.write(file)
    spec['stackedPdf'] = stacked_name
    spec['stackedPages'] = {
        'columns': columns,
        'gapPt': gap_pt,
        'cellSizePt': [round(cell_width, 4), round(cell_height, 4)],
        'offsetsPt': offsets,
    }
    json_path.write_text(json.dumps(spec, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'{json_path.name}: {n_pages} pages -> {stacked_name} ({columns} x {rows}, '
          f'{total_width/72*25.4:.0f} x {total_height/72*25.4:.0f} mm)')
    return True


def main(arguments):
    if not arguments:
        print(__doc__)
        sys.exit(1)
    count = 0
    for argument in arguments:
        path = Path(argument)
        if not path.exists():
            path = work_input_dir / argument  # 作業フォルダの input/ からの相対
        json_paths = sorted(path.glob('*.json')) if path.is_dir() else [path]
        for json_path in json_paths:
            count += stack_pages(json_path)
    print(f'stacked {count} file(s)')


if __name__ == '__main__':
    main(sys.argv[1:])
