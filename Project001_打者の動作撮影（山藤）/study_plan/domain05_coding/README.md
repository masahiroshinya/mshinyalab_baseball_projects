# 05_coding — Python / コーディング品質

目的:
- ノートブックの可読性と再現性を高め、エラーを早期発見できるようにする。

学習項目:
- NumPy 配列の取り扱い、reshape の理由
- OpenCV の色空間と画像入出力の注意点

実践タスク:
- 主要セルに `from tools.logger import log` を挿入してログを取る
- 小さなユニットテストを `tests/` に置く（例: `test_triangulation.py`）

検証:
- ノートブック実行時に主要イベントが `logs/agent_log.md` に記録される
- 基本的な unit test が通る

時間: 3–6 時間
