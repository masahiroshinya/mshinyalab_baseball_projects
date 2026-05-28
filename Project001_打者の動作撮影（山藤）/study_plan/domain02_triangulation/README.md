# 02_triangulation — 三角測量（Triangulation）

目的:
- `cv2.triangulatePoints` と同次座標の扱いを理解し、スケールの原因を切り分ける。

学習項目:
- 同次座標 (X,Y,Z,W) の W 除算の意味
- `undistortPoints` の `P` 引数の有無が出力に与える影響

実践タスク:
- `notebooks/triangulation_demo.ipynb` を作成
  - 既知の 3D 点を投影して三角測量で復元する実験
  - `SQUARE_LENGTH` を変えてスケール変化を確認

検証:
- 再投影誤差が小さいか
- SQUARE_LENGTH 変更で座標が線形にスケールするか

時間: 4–6 時間
