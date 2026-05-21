# Step09 実装ステップ2：キャリブレーションから3D立体起こしまでの一貫処理

作成日：2026-05-14
担当：山藤プロジェクト（進矢研究室）

---

## 概要

本ステップでは、「ソフト1（映像同期）」「ソフト2（キャリブレーション画像取得）」「ソフト3（分析フレーム指定）」の出力を受け取り、以下の5つの処理を**1つのスクリプトで順次実行**し、3D空間の立体座標を算出します。

1. **ステレオキャリブレーション (Stereo Calibration)**
   ソフト2で取得した画像からChArUcoボードのコーナーを検出し、各カメラの内部パラメータ（焦点距離、歪み係数）と外部パラメータ（カメラ間の回転行列 $R$、並進ベクトル $T$）を求めます。
2. **ステレオ平行化 (Stereo Rectification)**
   キャリブレーション結果を用いて、3D再構成に必要な投影行列（Projection Matrix: `P1`, `P2`）を計算します。これにより、2台のカメラの幾何学的な関係が定義されます。
3. **対応点の検出 (Correspondence point detection)**
   ソフト3で指定された分析対象フレーム区間に対し、YOLOv8-poseとYOLOv8を使用して、左右それぞれの画像から打者の関節（17点）とバットの2D座標を検出します。
4. **三角測量 (Triangulation)**
   左右のカメラで検出した対応する2D座標と、投影行列（P1, P2）を用いて、空間上の3D座標（X, Y, Z）を計算します。処理前にレンズ歪みの補正も実行します。
5. **3D起こし (3D Reconstruction)**
   算出されたすべてのフレームの3D座標を1つのCSVファイル（時系列データ）として保存します。

---

## 前提条件

- **実行環境**：Google Colab（T4 GPU 推奨）
- **入力データ**（ソフト1〜3の出力がColab環境にあること）：
  1. `cam1_synced.mp4`, `cam2_synced.mp4`：同期済み動画
  2. `task_frame_numbers.csv`：解析区間（start, end）が記録されたCSV
  3. `calib_cam1_xxx.jpg`, `calib_cam2_xxx.jpg`：キャリブレーション用画像

---

## ステップ 1：Google Colabの準備とパッケージインストール

新しいColabノートブックの最初のセルで必要なパッケージをインストールします。

```python
!pip install ultralytics opencv-contrib-python pandas numpy
```
※ `cv2.aruco` を使用するため、環境によっては `opencv-contrib-python` が必要です。

---

## ステップ 2：一貫処理の実行（キャリブレーション 〜 3D起こし）

次のセルに以下のスクリプトをコピー＆ペーストし実行します。
必要に応じて、設定ブロックのパスやChArUcoボードのサイズを調整してください。

```python
import os
import cv2
import pandas as pd
import numpy as np
import glob
from ultralytics import YOLO

# ============================================
# --- 1. 設定とファイルの準備 ---
# ============================================
# 入力ファイルのパス (ソフト1〜3の出力)
VIDEO1_PATH = "/content/cam1_synced.mp4"
VIDEO2_PATH = "/content/cam2_synced.mp4"
CSV_FRAMES_PATH = "/content/task_frame_numbers.csv"
CALIB_DIR = "/content/"  # calib_cam1_xxx.jpg が保存されている場所

# 出力ファイルのパス
OUTPUT_3D_CSV = "/content/batting_3d_tracking.csv"

# YOLOモデルの指定
POSE_MODEL_NAME = "yolov8m-pose.pt"
DETECT_MODEL_NAME = "yolov8m.pt"
BAT_CLASS_ID = 34  # COCOの 'baseball bat'

KEYPOINT_NAMES = [
    "nose", "left_eye", "right_eye", "left_ear", "right_ear",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist", "left_hip", "right_hip",
    "left_knee", "right_knee", "left_ankle", "right_ankle"
]

# キャリブレーションボード (ChArUco) の設定
# generate_charuco_a4.py の自動計算結果に合わせて修正してください
SQUARES_X = 8
SQUARES_Y = 6
SQUARE_LENGTH = 0.069  # m (69mm)
MARKER_LENGTH = 0.051  # m (51mm)
dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_250)
board = cv2.aruco.CharucoBoard((SQUARES_X, SQUARES_Y), SQUARE_LENGTH, MARKER_LENGTH, dictionary)

# ============================================
# --- 2. ステレオキャリブレーション ---
# ============================================
print("--- 1. ステレオキャリブレーションを開始します ---")

img_paths1 = sorted(glob.glob(f"{CALIB_DIR}calib_cam1_*.jpg"))
img_paths2 = sorted(glob.glob(f"{CALIB_DIR}calib_cam2_*.jpg"))

if not img_paths1 or not img_paths2:
    raise FileNotFoundError("キャリブレーション画像が見つかりません。CALIB_DIRを確認してください。")

all_corners1, all_ids1 = [], []
all_corners2, all_ids2 = [], []
image_size = None

# OpenCV 4.7以降用の ChArUco 検出器
charuco_detector = cv2.aruco.CharucoDetector(board)

# コーナー検出
for p1, p2 in zip(img_paths1, img_paths2):
    img1 = cv2.imread(p1)
    img2 = cv2.imread(p2)
    if img1 is None or img2 is None: continue
    gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
    gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)
    
    if image_size is None:
        image_size = (gray1.shape[1], gray1.shape[0])
    
    # Cam1 検出
    charuco_corners1, charuco_ids1, _, _ = charuco_detector.detectBoard(gray1)
    # Cam2 検出
    charuco_corners2, charuco_ids2, _, _ = charuco_detector.detectBoard(gray2)

    # 両カメラで6点以上検出されていればペアとして採用
    if (charuco_corners1 is not None and len(charuco_corners1) >= 6 and 
        charuco_corners2 is not None and len(charuco_corners2) >= 6):
        all_corners1.append(charuco_corners1)
        all_ids1.append(charuco_ids1)
        all_corners2.append(charuco_corners2)
        all_ids2.append(charuco_ids2)

print(f"有効キャリブレーションペア数: {len(all_corners1)}")

# ボードの全3Dコーナー座標を取得 (OpenCV バージョンによる差違吸収)
if hasattr(board, 'chessboardCorners'):
    board_corners = board.chessboardCorners
else:
    board_corners = board.getChessboardCorners()

# 単体キャリブレーション用の共通関数
def calibrate_single_camera(corners_list, ids_list, img_size):
    all_obj_pts = []
    all_img_pts = []
    for corners, ids in zip(corners_list, ids_list):
        obj_pts = np.array([board_corners[idx[0]] for idx in ids], dtype=np.float32).reshape(-1, 1, 3)
        all_obj_pts.append(obj_pts)
        all_img_pts.append(corners)
    # OSMO Action等の広角レンズ向けに CALIB_RATIONAL_MODEL を適用
    return cv2.calibrateCamera(all_obj_pts, all_img_pts, img_size, None, None, flags=cv2.CALIB_RATIONAL_MODEL)

# 単体キャリブレーション実行
ret1, mtx1, dist1, rvecs1, tvecs1 = calibrate_single_camera(all_corners1, all_ids1, image_size)
ret2, mtx2, dist2, rvecs2, tvecs2 = calibrate_single_camera(all_corners2, all_ids2, image_size)

# ステレオキャリブレーション用の共通点抽出
objpoints_stereo = []
imgpoints_cam1_stereo = []
imgpoints_cam2_stereo = []

for i in range(len(all_corners1)):
    # 共通のIDを抽出
    common_ids = np.intersect1d(all_ids1[i].flatten(), all_ids2[i].flatten())
    if len(common_ids) >= 6:
        idx1 = [np.where(all_ids1[i].flatten() == cid)[0][0] for cid in common_ids]
        idx2 = [np.where(all_ids2[i].flatten() == cid)[0][0] for cid in common_ids]
        
        obj_pts = np.array([board_corners[cid] for cid in common_ids], dtype=np.float32).reshape(-1, 1, 3)
        imgpoints_cam1_stereo.append(all_corners1[i][idx1])
        imgpoints_cam2_stereo.append(all_corners2[i][idx2])
        objpoints_stereo.append(obj_pts)

flags_stereo = cv2.CALIB_FIX_INTRINSIC
criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 0.001)

ret_stereo, mtx1, dist1, mtx2, dist2, R, T, E, F = cv2.stereoCalibrate(
    objpoints_stereo, imgpoints_cam1_stereo, imgpoints_cam2_stereo,
    mtx1, dist1, mtx2, dist2, image_size, criteria=criteria, flags=flags_stereo)

print(f"ステレオRMS誤差: {ret_stereo:.4f} px")

# ============================================
# --- 3. ステレオ平行化 ---
# ============================================
print("--- 2. ステレオ平行化（投影行列の計算）を開始します ---")
R1, R2, P1, P2, Q, roi1, roi2 = cv2.stereoRectify(
    mtx1, dist1, mtx2, dist2, image_size, R, T, flags=cv2.CALIB_ZERO_DISPARITY, alpha=0
)
print("投影行列 P1, P2 を算出しました。")

# ============================================
# --- 4. 対応点の検出 (YOLOによる2D姿勢推定) ---
# ============================================
print("--- 3. YOLOモデルによる対応点の検出を準備します ---")
pose_model = YOLO(POSE_MODEL_NAME)
detect_model = YOLO(DETECT_MODEL_NAME)

def get_2d_points(img):
    """画像から打者の17点の骨格座標とバットの中心座標を取得する"""
    # バット検出
    det_results = detect_model(img, verbose=False)
    bat_boxes = []
    for r in det_results:
        for i in range(len(r.boxes)):
            if int(r.boxes.cls[i].item()) == BAT_CLASS_ID:
                bat_boxes.append(r.boxes.xyxy[i].tolist() + [float(r.boxes.conf[i].item())])
    
    best_bat = None
    if bat_boxes:
        bat_boxes.sort(key=lambda x: x[4], reverse=True)
        best_bat = bat_boxes[0]

    # 姿勢推定
    pose_results = pose_model(img, verbose=False)
    target_person_kps = None
    
    for r in pose_results:
        if r.keypoints is None or len(r.keypoints.data) == 0:
            continue
            
        kps_data = r.keypoints.data.cpu().numpy()
        boxes_data = r.boxes.xyxy.cpu().numpy()
        
        if best_bat is not None:
            bx1, by1, bx2, by2, _ = best_bat
            bcx, bcy = (bx1+bx2)/2, (by1+by2)/2
            min_dist = float('inf')
            best_p_idx = -1
            for p_idx, p_box in enumerate(boxes_data):
                px1, py1, px2, py2 = p_box
                pcx, pcy = (px1+px2)/2, (py1+py2)/2
                dist = np.hypot(bcx - pcx, bcy - pcy)
                if dist < min_dist:
                    min_dist = dist
                    best_p_idx = p_idx
            if best_p_idx != -1:
                target_person_kps = kps_data[best_p_idx]
        else:
            max_area = 0
            best_p_idx = -1
            for p_idx, p_box in enumerate(boxes_data):
                area = (p_box[2]-p_box[0]) * (p_box[3]-p_box[1])
                if area > max_area:
                    max_area = area
                    best_p_idx = p_idx
            if best_p_idx != -1:
                target_person_kps = kps_data[best_p_idx]

    kps = target_person_kps[:, :2] if target_person_kps is not None else None
    bat_center = np.array([(best_bat[0]+best_bat[2])/2, (best_bat[1]+best_bat[3])/2]) if best_bat is not None else None
        
    return kps, bat_center

# ============================================
# --- 5. 三角測量と3D起こし ---
# ============================================
print("--- 4 & 5. 三角測量と3D起こしを開始します ---")
df_frames = pd.read_csv(CSV_FRAMES_PATH)

# startとendからフレームのリストを生成
if 'type' in df_frames.columns and 'frame_number' in df_frames.columns:
    start_frame = int(df_frames[df_frames['type'] == 'start']['frame_number'].values[0])
    end_frame = int(df_frames[df_frames['type'] == 'end']['frame_number'].values[0])
    target_frames = list(range(start_frame, end_frame + 1))
else:
    target_frames = df_frames.iloc[:, -1].dropna().astype(int).tolist()

cap1 = cv2.VideoCapture(VIDEO1_PATH)
cap2 = cv2.VideoCapture(VIDEO2_PATH)

results_3d = []

for frame_no in target_frames:
    print(f"Processing Frame: {frame_no}")
    cap1.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
    cap2.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
    
    ret1, img1 = cap1.read()
    ret2, img2 = cap2.read()
    
    if not (ret1 and ret2):
        print(f"  Frame {frame_no} を読み込めませんでした。スキップします。")
        continue

    # 対応点の検出
    kps1, bat1 = get_2d_points(img1)
    kps2, bat2 = get_2d_points(img2)
    
    row_data = {"frame_number": frame_no}
    
    # ---- 三角測量用の投影行列を定義（正規化座標系） ----
    # undistortPoints に P= を渡さない → 正規化カメラ座標（焦点距離・主点を除去した座標）を取得
    # その場合の投影行列は「カメラ1は原点 [I|0]」「カメラ2は [R|T]」になる
    P1_norm = np.hstack([np.eye(3),  np.zeros((3, 1))])   # カメラ1：原点
    P2_norm = np.hstack([R,          T])                   # カメラ2：ステレオキャリブ結果

    # 骨格の三角測量
    if kps1 is not None and kps2 is not None:
        pts1_norm = cv2.undistortPoints(np.expand_dims(kps1, axis=1), mtx1, dist1)
        pts2_norm = cv2.undistortPoints(np.expand_dims(kps2, axis=1), mtx2, dist2)
        
        pts4d = cv2.triangulatePoints(P1_norm, P2_norm,
                                      pts1_norm.reshape(-1, 2).T,
                                      pts2_norm.reshape(-1, 2).T)
        pts3d = (pts4d[:3, :] / pts4d[3, :]).T
        
        for i, kp_name in enumerate(KEYPOINT_NAMES):
            row_data[f"{kp_name}_X"] = round(pts3d[i, 0], 4)
            row_data[f"{kp_name}_Y"] = round(pts3d[i, 1], 4)
            row_data[f"{kp_name}_Z"] = round(pts3d[i, 2], 4)
    else:
        for kp_name in KEYPOINT_NAMES:
            row_data[f"{kp_name}_X"] = row_data[f"{kp_name}_Y"] = row_data[f"{kp_name}_Z"] = ""

    # バットの三角測量
    if bat1 is not None and bat2 is not None:
        b_pts1_norm = cv2.undistortPoints(np.expand_dims(bat1.reshape(1, 2), axis=1), mtx1, dist1)
        b_pts2_norm = cv2.undistortPoints(np.expand_dims(bat2.reshape(1, 2), axis=1), mtx2, dist2)
        
        b_pts4d = cv2.triangulatePoints(P1_norm, P2_norm,
                                        b_pts1_norm.reshape(2, 1),
                                        b_pts2_norm.reshape(2, 1))
        b_pts3d = (b_pts4d[:3, :] / b_pts4d[3, :]).flatten()
        
        row_data["bat_X"] = round(b_pts3d[0], 4)
        row_data["bat_Y"] = round(b_pts3d[1], 4)
        row_data["bat_Z"] = round(b_pts3d[2], 4)
    else:
        row_data["bat_X"] = row_data["bat_Y"] = row_data["bat_Z"] = ""

    results_3d.append(row_data)

cap1.release()
cap2.release()

if results_3d:
    df_out = pd.DataFrame(results_3d)
    df_out.to_csv(OUTPUT_3D_CSV, index=False)
    print("=" * 50)
    print(f"✅ 3D座標の立体起こしが完了しました！")
    print(f"   保存先: {OUTPUT_3D_CSV}")
    print("=" * 50)
else:
    print("\n⚠️ 処理できるフレームがありませんでした。")
```

---

## ステップ 3：出力結果の確認

実行が完了すると、Colab のファイルリスト内に **`batting_3d_tracking.csv`** が作成されます。

- 1つのスクリプト内で、**キャリブレーション → ステレオ平行化 → 2D推論（対応点検出） → 三角測量 → 3D起こし** をシームレスに実行しました。
- 各列には、打者の17点の骨格座標およびバット中心の **X, Y, Z空間座標** が出力されています。
- このCSVデータを用いて、OpenSim等の生体力学解析ソフトへ変換したり、Matplotlibで3Dプロットしたりすることが可能です。
