#!/bin/zsh
# draft.md → docx 変換（sandbox/6.1_Pandoc/技術説明.md の方式）
# 使い方：このフォルダで  ./convert.sh  （出力ファイル名を変えるなら ./convert.sh 出力名.docx）
cd "$(dirname "$0")"
OUT="${1:-2026野球学会抄録_加藤.docx}"
BIB="../../../sandbox/6.1_Pandoc/reference/選択反応課題　参考文献.bib"
pandoc draft.md -o "$OUT" -V lang=ja \
  --reference-doc=reference.docx \
  --citeproc --bibliography="$BIB" \
  --csl="$HOME/Zotero/styles/nature.csl" \
  && echo "出力：$OUT"
