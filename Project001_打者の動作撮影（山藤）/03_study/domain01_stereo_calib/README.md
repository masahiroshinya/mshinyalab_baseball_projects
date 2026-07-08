# 01_stereo_calib — ステレオキャリブレーション

目的:
- 正しい `SQUARE_LENGTH` と画像ペアでステレオキャリブを行い、`R` と `T` の物理的意味を理解する。

学習項目:
- `cv2.calibrateCamera` と `cv2.stereoCalibrate` の引数と出力
- ChArUco の角検出とオブジェクトポイント生成方法

実践タスク:
- `notebooks/experiment_calib.ipynb` を作成し、保存済みキャリブ画像で再現
- 外れ値除去の挙動を観察し、どのフレームを除外したかログする

検証チェックリスト:
- `SQUARE_LENGTH` が実測の mm → m に変換されている
- `np.linalg.norm(T)` が実測のカメラ間距離と概ね一致する
- ステレオRMS が 2.0px 以下に低下するか（外れ値除去後）

時間: 6–10 時間

参考:
- OpenCV docs: stereoCalibrate

---

## 基礎ノート: ステレオキャリブレーション

- `K` は内部パラメータ行列。焦点距離 `fx, fy` と主点 `cx, cy` を持つ。単位はピクセルで、カメラ座標系から画像座標系への投影を決める。
- `dist` は歪み補正係数。レンズの放射歪み・接線歪みを表す。カメラ間距離ではない。
- `R` はカメラ1座標系からカメラ2座標系への回転行列。2台の向きの違いを表す。
- `T` はカメラ1座標系から見たカメラ2の位置ベクトル。`np.linalg.norm(T)` はカメラ間のベースライン距離に相当するが、単位は `SQUARE_LENGTH` の設定に依存する。
- 再投影誤差は「観測した2Dコーナー位置」と「推定したパラメータで投影した2D位置」の差のL2ノルムを平均したもの。これが小さいほどキャリブ結果が入力点に整合している。
- `cv2.stereoCalibrate` は最適化によって `K1, dist1, K2, dist2, R, T` を求める。初期値やフラグによって収束結果が変わることがある。
- 典型的な問題パターン:
  - 画像ペアの対応がずれている
  - コーナー検出が失敗している
  - 外れ値が混入している
  - ファイル順序が逆になっている（cam1/cam2）
  - `SQUARE_LENGTH` の単位が間違っている

### 重点チェック

- `K` の `cx, cy` が画像中心付近か
- `dist` が極端に大きくないか
- `R` が単位行列に近ければカメラはほぼ平行配置
- `T` の大きさが物理的に妥当か

---

演習問題（Step-by-step）:

1) 画像確認と前処理（1時間）
 - 配布されたキャリブ画像フォルダを確認し、解像度と撮影条件を記録する。
 - チャルコ（ChArUco）検出率が低いフレームを一覧化する（`failed_frames.csv`）。

2) 単眼キャリブレーション（1.5時間）
 - `notebooks/experiment_calib.ipynb` の Section 6 を使い、単眼カメラ行列 `camera_matrix` と `dist_coeff` を求め、`calibration_results/` に YAML で保存する。
 - 再投影誤差をプロットして、閾値 2.0 px を満たすか確認する。

3) ステレオキャリブ（2時間）
 - 十分に検出できた画像ペアで `cv2.stereoCalibrate` を実行。`CALIB_FIX_INTRINSIC` を使う場合と使わない場合で比較する。
 - 各ペアの再投影誤差を算出し、外れ値フレームを除去して再実行する。

4) Triangulation 確認（1.5時間）
 - 校正行列を使って既知のボード角の 3D 座標を三角測量し、物理寸法（例: ボード幅）と一致するか確認する。
 - 異常に大きなスケールが出るときは、カメラのファイルパス順（cam1/cam2）が正しいか確認する。

5) レポート作成（1時間）
 - `results/` に以下をまとめる：`camera1.yaml`, `camera2.yaml`, `stereo_params.yaml`, 再投影誤差プロット（PNG）、外れ値リスト、短い所見（README 内に md）。

提出物:
 - `calibration_results/camera1.yaml`, `camera2.yaml`, `stereo_params.yaml`
 - `results/reprojection_plot.png`
 - `results/outliers.txt`（除外したフレーム名）
 - `results/short_report.md`

ヒントとチェックリスト:
 - `SQUARE_LENGTH` は mm で測ったなら m に換算して設定する。例えば 69 mm -> 0.069 m。
 - `np.linalg.norm(T)` の単位は `SQUARE_LENGTH` に依存する（設定ミスで桁違いの値が出る）。
 - ファイル名の順序ミス（cam1とcam2が逆）でスケールが狂うことが多い。
 - 実行ログは `from tools.logger import log` を使って主要イベント（キャリブ開始/終了、RMS 値、外れ値）を書き残す。

推定時間: 6–10 時間（データ品質に依存）
