# Project001 打者の動作撮影

野球打者のバッティング動作を、マーカーレスモーションキャプチャーで撮影・解析するプロジェクト。

## どこを見るか

| フォルダ | 用途 |
| --- | --- |
| `00_project/` | プロジェクト概要、技術課題、基本情報 |
| `01_research/` | 文献、PDF、調査メモ、先行研究まとめ |
| `sandbox/` | 先生との作業で使うStep別の実装・検証場所 |
| `02_experiments/` | 実験ノートブックなど、sandbox以外の実験補助 |
| `03_study/` | 学習計画、理解マップ |
| `04_presentations/` | 発表資料。発表日ごとに管理 |
| `05_tasks/` | todo、作業管理 |
| `06_tools/` | 補助ツール、ロガー |
| `99_logs/` | AIとの作業ログ |

## 発表資料の置き方

発表資料は `04_presentations/YYYY-MM-DD_topic/` に置く。

- `draft_ai/`: AIが作った下書き、生成pptx、構成案
- `final_human/`: 人間が確認・編集した完成版
- `tools/`: その発表資料を生成するスクリプト

## 文献の置き方

文献は `01_research/` に集約する。

- `survey/`: AIが条件に沿って文献を探した検索ログ
- `research_comp/`: 論文ごとの要約、全文メモ、翻訳文
- `notes/`: ユーザー本人が書く考察・研究への接続
- `pdfs/`: PDF本体
- `materials/`: 図、スライドなどの資料

## 旧構成からの変更

- `previous_research/` と `research_notes/` は `01_research/` に統合
- `notebooks/` は `02_experiments/` に移動
- `sandbox/` は先生との共同作業場所としてルート直下に維持
- `presen/` は `04_presentations/` に移行
- `logs/` は `99_logs/` に移行
