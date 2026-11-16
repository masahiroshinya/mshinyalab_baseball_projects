#!/bin/zsh
# draft.md → docx 変換（sandbox/6.1_Pandoc/技術説明.md の方式）
# 使い方：このフォルダで  ./convert.sh  （出力ファイル名を変えるなら ./convert.sh 出力名.docx）
# 文献を引用しないので、--citeproc・.bib・CSL は付けていない。
# PDF は、できた docx を Word で開いて「名前を付けて保存 → PDF」。
cd "$(dirname "$0")"
OUT="${1:-ヘッドスピード変化率_計算の説明.docx}"
pandoc draft.md -o "$OUT" -V lang=ja \
  --reference-doc=reference.docx \
  --resource-path=.:figure \
  && echo "出力：$OUT"
