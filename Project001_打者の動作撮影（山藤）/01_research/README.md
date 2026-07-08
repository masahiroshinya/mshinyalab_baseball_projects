# 01_research

先行研究を扱う場所。役割は次のように分ける。

## フォルダ

| フォルダ | 用途 |
| --- | --- |
| `survey/` | AIが条件に沿って文献を探した検索ログ。検索語、ヒット文献、評価点を残す |
| `research_comp/` | 論文ごとの要約、全文メモ、翻訳文。ファイル名は `title_著者名.md` |
| `notes/` | ユーザーが操作する考察領域。先行研究を自分の研究へどうつなげるか、研究計画への反映を書く |
| `pdfs/` | PDF本体 |
| `materials/` | PDF以外の資料、図、スライドなど |
| `_templates/` | 文献整理用テンプレート |
| `_tools/` | 文献検索や整理用の補助メモ・ツール |

## 使い方

1. AIに文献を探させたら、結果を `survey/YYYY_MM_DD.md` に保存する。
2. 読みたい文献を選んだら、`research_comp/title_著者名.md` に要約・翻訳・本文メモを作る。
3. その文献が自分の研究にどう効くかは、`notes/` に自分の言葉で書く。

## AI操作ルール

- AIは原則として `notes/` 内のファイルを作成・編集・移動・削除しない。
- `notes/` はユーザー本人が考察や研究へのつなげ方を書く場所として扱う。
- AIが `notes/` に関わる必要がある場合は、先に提案だけ行い、ユーザーから明示的な許可があったときだけ操作する。
- AIが通常作業で使う保存先は、探索結果なら `survey/`、論文ごとの要約・翻訳なら `research_comp/`、PDFや資料なら `pdfs/` または `materials/` とする。

## 現在の配置

- `survey/2026_07_08.md`: 投動作の複雑性と即時・拡張フィードバックの探索
- `research_comp/Hitting_a_baseball_a_biomechanical_description_Welch.md`: 野球打撃動作
- `research_comp/The_effect_of_augmented_feedback_on_gross_motor_and_sport_specific_skills_Petancevski.md`: 拡張フィードバック総説
- `research_comp/Impact_of_augmented_video_verbal_encouragement_feedback_on_novice_cricket_athletes_Basri.md`: クリケットの動画・言語フィードバック
