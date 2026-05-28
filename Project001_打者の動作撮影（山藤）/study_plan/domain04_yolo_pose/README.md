# 04_yolo_pose — YOLO / Pose Estimation

目的:
- 2D キーポイント検出の信頼性を上げ、3D 再構成に適した入力を作る。

学習項目:
- YOLOv8 Pose の出力構造（keypoints, boxes, confidence）
- 検出失敗パターン（被写体小さい・遮蔽・逆光）

実践タスク:
- `notebooks/pose_quality_check.ipynb` を作成
  - スライダ付き 2D オーバーレイ（既存セルの拡張）
  - 失敗フレームを集計して `pose_failures.csv` を出力

検証:
- 失敗率 < 10% を目指す（閾値はプロジェクト次第）
- 面積最大の検出が常に打者であるかを確認

時間: 6–8 時間
