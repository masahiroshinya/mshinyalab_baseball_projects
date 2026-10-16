#!/bin/zsh
# draft.md → docx 変換（sandbox/6.1_Pandoc/技術説明.md の方式）
# 使い方：このフォルダで  ./convert.sh  （出力ファイル名を変えるなら ./convert.sh 出力名.docx）
cd "$(dirname "$0")"
OUT="${1:-研究概要.docx}"
BIB="../../../sandbox/6.1_Pandoc/reference/選択反応課題　参考文献.bib"
pandoc draft.md -o "$OUT" -V lang=ja \
  --reference-doc=reference.docx \
  --resource-path=.:figure \
  --citeproc --bibliography="$BIB" \
  --csl="$HOME/Zotero/styles/apa.csl" \
  && echo "出力：$OUT"
