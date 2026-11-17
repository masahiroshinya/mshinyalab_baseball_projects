#!/bin/zsh
# draft.md → docx 変換（sandbox/6.1_Pandoc/技術説明.md の方式）
# 使い方：このフォルダで  ./convert.sh  （出力ファイル名を変えるなら ./convert.sh 出力名.docx）
# 文献を引用しないので、--citeproc・.bib・CSL は付けていない。
# reference.docx は ../計算の説明 のものに、A4・日本語（ja-JP、settings の themeFontLang も ja-JP、游ゴシック）・本文 10.5 pt・段落の間隔・図の中央揃えを足したもの（2026-11-17）。
# PDF は、できた docx を Word で開いて「名前を付けて保存 → PDF」。
cd "$(dirname "$0")"
OUT="${1:-ヘッドスピード変化率_検定結果_返信_試行単位.docx}"
pandoc draft.md -o "$OUT" -V lang=ja-JP \
  --reference-doc=reference.docx \
  --resource-path=.:figure \
  && echo "出力：$OUT"
