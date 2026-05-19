# 3D打者モーション再構成 ── 実行パイプライン（完全版）

作成日：2026-05-18（今日の修正をすべて反映済み）

---

## アップロードしておくファイル（Colab にドラッグ＆ドロップ）

| ファイル | 説明 |
|---------|------|
| `cam1_synced.mp4` | ソフト1 の出力（同期済みカメラ1） |
| `cam2_synced.mp4` | ソフト1 の出力（同期済みカメラ2） |
| `task_frame_numbers.csv` | ソフト3 の出力（解析フレーム区間） |
| `calib_cam1_001.jpg` … | ソフト2 の出力（キャリブ画像 各11枚） |
| `calib_cam2_001.jpg` … | ソフト2 の出力（キャリブ画像 各11枚） |

---

## セル 1：パッケージインストール

```python
!pip install ultralytics opencv-contrib-python pandas numpy ipywidgets matplotlib -q
```

---

## セル 2：ライブラリ・設定

```python
import os, cv2, glob
import pandas as pd
import numpy as np
from ultralytics import YOLO

# ============================================================
# ▼ パス設定（変更不要）
# ============================================================
VIDEO1_PATH    = "/content/cam1_synced.mp4"
VIDEO2_PATH    = "/content/cam2_synced.mp4"
CSV_FRAMES_PATH = "/content/task_frame_numbers.csv"
CALIB_DIR      = "/content/"
OUTPUT_3D_CSV  = "/content/batting_3d_tracking.csv"

# ============================================================
# ▼ YOLOモデル
# ============================================================
POSE_MODEL_NAME   = "yolov8m-pose.pt"
DETECT_MODEL_NAME = "yolov8m.pt"
BAT_CLASS_ID      = 34   # COCO: 'baseball bat'

KEYPOINT_NAMES = [
    "nose", "left_eye", "right_eye", "left_ear", "right_ear",
    "left_shoulder", "right_shoulder", "left_elbow", "right_elbow",
    "left_wrist", "right_wrist", "left_hip", "right_hip",
    "left_knee", "right_knee", "left_ankle", "right_ankle"
]

# ============================================================
# ▼ ChArUco ボード設定（実測値 2026-05-18 確定）
# ============================================================
SQUARES_X     = 8
SQUARES_Y     = 6
SQUARE_LENGTH = 0.135   # m（実測 135 mm）← 今日確定した値
MARKER_LENGTH = 0.101   # m（実測 101 mm）← 今日確定した値

dictionary = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_4X4_250)
board = cv2.aruco.CharucoBoard(
    (SQUARES_X, SQUARES_Y), SQUARE_LENGTH, MARKER_LENGTH, dictionary)

print("✅ 設定完了")
print(f"   SQUARE_LENGTH = {SQUARE_LENGTH*1000:.0f} mm")
print(f"   MARKER_LENGTH = {MARKER_LENGTH*1000:.0f} mm")
```

---

## セル 3：ステレオキャリブレーション

```python
# ============================================================
# ChArUco コーナー検出
# ============================================================
print("--- ステレオキャリブレーション開始 ---")

img_paths1 = sorted(glob.glob(f"{CALIB_DIR}calib_cam1_*.jpg"))
img_paths2 = sorted(glob.glob(f"{CALIB_DIR}calib_cam2_*.jpg"))

if not img_paths1 or not img_paths2:
    raise FileNotFoundError("キャリブレーション画像が見つかりません")

all_corners1, all_ids1 = [], []
all_corners2, all_ids2 = [], []
image_size = None

charuco_detector = cv2.aruco.CharucoDetector(board)

for p1, p2 in zip(img_paths1, img_paths2):
    img1 = cv2.imread(p1)
    img2 = cv2.imread(p2)
    if img1 is None or img2 is None:
        continue
    gray1 = cv2.cvtColor(img1, cv2.COLOR_BGR2GRAY)
    gray2 = cv2.cvtColor(img2, cv2.COLOR_BGR2GRAY)

    if image_size is None:
        image_size = (gray1.shape[1], gray1.shape[0])

    c1, ids1, _, _ = charuco_detector.detectBoard(gray1)
    c2, ids2, _, _ = charuco_detector.detectBoard(gray2)

    if (c1 is not None and len(c1) >= 6 and
        c2 is not None and len(c2) >= 6):
        all_corners1.append(c1);  all_ids1.append(ids1)
        all_corners2.append(c2);  all_ids2.append(ids2)

print(f"有効キャリブペア数: {len(all_corners1)}")

# ---- board の3D座標取得 ----
if hasattr(board, 'chessboardCorners'):
    board_corners = board.chessboardCorners
else:
    board_corners = board.getChessboardCorners()

# ============================================================
# 単体キャリブレーション（k3固定・発散防止）
# ============================================================
def calibrate_single_camera(corners_list, ids_list, img_size):
    all_obj_pts, all_img_pts = [], []
    for corners, ids in zip(corners_list, ids_list):
        obj_pts = np.array([board_corners[idx[0]] for idx in ids],
                           dtype=np.float32).reshape(-1, 1, 3)
        all_obj_pts.append(obj_pts)
        all_img_pts.append(corners)
    # 初期焦点距離を画像幅の0.8倍に設定、k3のみ固定して収束を安定化
    fx_init = img_size[0] * 0.8
    K_init = np.array([[fx_init, 0, img_size[0]/2],
                       [0, fx_init, img_size[1]/2],
                       [0, 0, 1]], dtype=np.float64)
    flags = cv2.CALIB_USE_INTRINSIC_GUESS | cv2.CALIB_FIX_K3
    return cv2.calibrateCamera(
        all_obj_pts, all_img_pts, img_size, K_init, None, flags=flags)

ret1, mtx1, dist1, rvecs1, tvecs1 = calibrate_single_camera(
    all_corners1, all_ids1, image_size)
ret2, mtx2, dist2, rvecs2, tvecs2 = calibrate_single_camera(
    all_corners2, all_ids2, image_size)

print(f"Cam1 単独RMS: {ret1:.4f} px   dist: {dist1.flatten()[:2]}")
print(f"Cam2 単独RMS: {ret2:.4f} px   dist: {dist2.flatten()[:2]}")

# ============================================================
# ステレオキャリブレーション
# ============================================================
objpoints_stereo, imgpoints_cam1_stereo, imgpoints_cam2_stereo = [], [], []

for i in range(len(all_corners1)):
    common_ids = np.intersect1d(all_ids1[i].flatten(), all_ids2[i].flatten())
    if len(common_ids) >= 6:
        idx1 = [np.where(all_ids1[i].flatten() == c)[0][0] for c in common_ids]
        idx2 = [np.where(all_ids2[i].flatten() == c)[0][0] for c in common_ids]
        obj_pts = np.array([board_corners[c] for c in common_ids],
                           dtype=np.float32).reshape(-1, 1, 3)
        objpoints_stereo.append(obj_pts)
        imgpoints_cam1_stereo.append(all_corners1[i][idx1])
        imgpoints_cam2_stereo.append(all_corners2[i][idx2])

criteria = (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 100, 1e-6)
ret_stereo, mtx1, dist1, mtx2, dist2, R, T, E, F = cv2.stereoCalibrate(
    objpoints_stereo, imgpoints_cam1_stereo, imgpoints_cam2_stereo,
    mtx1, dist1, mtx2, dist2, image_size,
    criteria=criteria, flags=cv2.CALIB_FIX_INTRINSIC)

print(f"\nステレオRMS: {ret_stereo:.4f} px  ← 2.0px 以下が目安")
print(f"カメラ間距離: {np.linalg.norm(T)*100:.1f} cm")
print(f"T = {T.flatten()}")
```

---

## セル 4：2D検出 → 三角測量 → CSV 出力

```python
# ============================================================
# YOLOモデルのロード
# ============================================================
print("--- YOLOモデルをロード中 ---")
pose_model   = YOLO(POSE_MODEL_NAME)
detect_model = YOLO(DETECT_MODEL_NAME)

def get_2d_points(img):
    """1枚の画像から骨格17点とバット中心を返す"""
    # ---- 骨格（最大の人物を選択）----
    results_pose = pose_model(img, verbose=False)
    kps = None
    if results_pose and results_pose[0].keypoints is not None:
        kp_data = results_pose[0].keypoints.xy.cpu().numpy()
        if len(kp_data) > 0:
            # 最も大きなバウンディングボックスの人物を選択
            boxes = results_pose[0].boxes
            if boxes is not None and len(boxes) > 0:
                areas = [(b[2]-b[0])*(b[3]-b[1])
                         for b in boxes.xyxy.cpu().numpy()]
                best = int(np.argmax(areas))
            else:
                best = 0
            kps = kp_data[best][:, :2]

    # ---- バット検出 ----
    results_det = detect_model(img, verbose=False)
    best_bat = None
    best_bat_conf = 0
    if results_det and results_det[0].boxes is not None:
        for box in results_det[0].boxes:
            cls = int(box.cls.item())
            conf = float(box.conf.item())
            if cls == BAT_CLASS_ID and conf > best_bat_conf:
                best_bat = box.xyxy.cpu().numpy()[0]
                best_bat_conf = conf

    bat_center = None
    if best_bat is not None:
        bat_center = np.array([(best_bat[0]+best_bat[2])/2,
                               (best_bat[1]+best_bat[3])/2])
    return kps, bat_center

# ============================================================
# 三角測量用投影行列（正規化座標系）
# undistortPoints に P= を渡さない → 正規化カメラ座標
# → P1_norm = [I|0]、P2_norm = [R|T] を使う
# ============================================================
P1_norm = np.hstack([np.eye(3), np.zeros((3, 1))])
P2_norm = np.hstack([R, T])

# ============================================================
# フレームループ
# ============================================================
print("--- 三角測量と3D起こしを開始します ---")
df_frames = pd.read_csv(CSV_FRAMES_PATH)

if 'type' in df_frames.columns:
    start_frame = int(df_frames[df_frames['type'] == 'start']['frame_number'].values[0])
    end_frame   = int(df_frames[df_frames['type'] == 'end']['frame_number'].values[0])
    target_frames = list(range(start_frame, end_frame + 1))
else:
    target_frames = df_frames.iloc[:, -1].dropna().astype(int).tolist()

cap1 = cv2.VideoCapture(VIDEO1_PATH)
cap2 = cv2.VideoCapture(VIDEO2_PATH)
results_3d = []

for frame_no in target_frames:
    print(f"  Processing Frame: {frame_no}", end="\r")
    cap1.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
    cap2.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
    ret1_v, img1 = cap1.read()
    ret2_v, img2 = cap2.read()

    if not (ret1_v and ret2_v):
        continue

    kps1, bat1 = get_2d_points(img1)
    kps2, bat2 = get_2d_points(img2)
    row_data = {"frame_number": frame_no}

    # ---- 骨格の三角測量 ----
    if kps1 is not None and kps2 is not None:
        pts1_n = cv2.undistortPoints(np.expand_dims(kps1, 1), mtx1, dist1)
        pts2_n = cv2.undistortPoints(np.expand_dims(kps2, 1), mtx2, dist2)
        pts4d  = cv2.triangulatePoints(
            P1_norm, P2_norm,
            pts1_n.reshape(-1, 2).T,
            pts2_n.reshape(-1, 2).T)
        pts3d  = (pts4d[:3] / pts4d[3]).T
        for i, name in enumerate(KEYPOINT_NAMES):
            row_data[f"{name}_X"] = round(pts3d[i, 0], 4)
            row_data[f"{name}_Y"] = round(pts3d[i, 1], 4)
            row_data[f"{name}_Z"] = round(pts3d[i, 2], 4)
    else:
        for name in KEYPOINT_NAMES:
            row_data[f"{name}_X"] = row_data[f"{name}_Y"] = row_data[f"{name}_Z"] = ""

    # ---- バットの三角測量 ----
    if bat1 is not None and bat2 is not None:
        b1_n = cv2.undistortPoints(bat1.reshape(1,1,2), mtx1, dist1)
        b2_n = cv2.undistortPoints(bat2.reshape(1,1,2), mtx2, dist2)
        b4d  = cv2.triangulatePoints(
            P1_norm, P2_norm, b1_n.reshape(2,1), b2_n.reshape(2,1))
        b3d  = (b4d[:3] / b4d[3]).flatten()
        row_data["bat_X"] = round(b3d[0], 4)
        row_data["bat_Y"] = round(b3d[1], 4)
        row_data["bat_Z"] = round(b3d[2], 4)
    else:
        row_data["bat_X"] = row_data["bat_Y"] = row_data["bat_Z"] = ""

    results_3d.append(row_data)

cap1.release()
cap2.release()

if results_3d:
    df_out = pd.DataFrame(results_3d)
    df_out.to_csv(OUTPUT_3D_CSV, index=False)
    print(f"\n✅ CSV 保存完了: {OUTPUT_3D_CSV}")
    print(f"   フレーム数: {len(df_out)}")
else:
    print("\n⚠️ 処理できるフレームがありませんでした")
```

---

## セル 5：スケール確認（念のため実行）

```python
df_check = pd.read_csv(OUTPUT_3D_CSV)
valid = df_check[pd.to_numeric(df_check["nose_X"], errors="coerce").notna()]
print(f"有効フレーム数: {len(valid)}")

# 肩幅を計算（0.30〜0.45m なら正常）
row = valid.iloc[len(valid)//2]
ls = np.array([float(row[f"left_shoulder_{a}"]) for a in "XYZ"])
rs = np.array([float(row[f"right_shoulder_{a}"]) for a in "XYZ"])
w  = np.linalg.norm(ls - rs)
print(f"肩幅（3D距離）: {w:.3f} m  ← 0.30〜0.45m が目標")
```

---

## セル 6：3画面スライダー可視化

```python
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import ipywidgets as widgets
from IPython.display import display, clear_output

# ============================================================
# パス設定
# ============================================================
VIDEO1_PATH = "/content/cam1_synced.mp4"
VIDEO2_PATH = "/content/cam2_synced.mp4"
CSV_3D_PATH = "/content/batting_3d_tracking.csv"

AXIS_RANGE = 1.5   # 3D軸の表示範囲 ±[m]
VIEW_ELEV  = 15
VIEW_AZIM  = -80

# ============================================================
# 骨格定義
# ============================================================
KP_NAMES = [
    "nose","left_eye","right_eye","left_ear","right_ear",
    "left_shoulder","right_shoulder","left_elbow","right_elbow",
    "left_wrist","right_wrist","left_hip","right_hip",
    "left_knee","right_knee","left_ankle","right_ankle"
]
SKELETON = [
    (0,1),(0,2),(1,3),(2,4),(5,6),
    (5,7),(7,9),(6,8),(8,10),
    (5,11),(6,12),(11,12),
    (11,13),(13,15),(12,14),(14,16),
]

# ============================================================
# データ読み込み
# ============================================================
df = pd.read_csv(CSV_3D_PATH)
valid = pd.to_numeric(df["nose_X"], errors="coerce").notna()
df_valid = df[valid].copy().reset_index(drop=True)
frame_list = df_valid["frame_number"].astype(int).tolist()

all_x, all_y, all_z = [], [], []
for kp in KP_NAMES:
    for col, lst in [(f"{kp}_X", all_x), (f"{kp}_Y", all_y), (f"{kp}_Z", all_z)]:
        vals = pd.to_numeric(df_valid.get(col, pd.Series()), errors="coerce").dropna()
        lst.extend(vals.tolist())

MID_X = float(np.mean(all_x)) if all_x else 0.0
MID_Y = float(np.mean(all_y)) if all_y else 0.0
MID_Z = float(np.mean(all_z)) if all_z else 0.0

cap1 = cv2.VideoCapture(VIDEO1_PATH)
cap2 = cv2.VideoCapture(VIDEO2_PATH)

def read_frame(cap, frame_no):
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
    ok, img = cap.read()
    return cv2.cvtColor(img, cv2.COLOR_BGR2RGB) if ok else np.zeros((480,640,3),dtype=np.uint8)

def get_kps(row):
    pts = []
    for kp in KP_NAMES:
        x = pd.to_numeric(row.get(f"{kp}_X", np.nan), errors="coerce")
        y = pd.to_numeric(row.get(f"{kp}_Y", np.nan), errors="coerce")
        z = pd.to_numeric(row.get(f"{kp}_Z", np.nan), errors="coerce")
        pts.append(None if any(np.isnan([x,y,z])) else (float(x),float(y),float(z)))
    return pts

print(f"✅ 有効フレーム数: {len(frame_list)}")

# ============================================================
# 描画関数
# ============================================================
def show_frame(idx):
    clear_output(wait=True)
    frame_no = frame_list[idx]
    row  = df_valid[df_valid["frame_number"] == frame_no].iloc[0]
    img1 = read_frame(cap1, frame_no)
    img2 = read_frame(cap2, frame_no)
    pts  = get_kps(row)
    bat  = None
    if "bat_X" in row.index and pd.notna(row["bat_X"]):
        bat = (float(row["bat_X"]), float(row["bat_Y"]), float(row["bat_Z"]))

    fig = plt.figure(figsize=(18, 6))
    fig.patch.set_facecolor("#111827")

    ax1 = fig.add_subplot(1, 3, 1)
    ax1.imshow(img1)
    ax1.set_title(f"📷 Camera 1  |  Frame {frame_no}", color="white", fontsize=11)
    ax1.axis("off")

    ax2 = fig.add_subplot(1, 3, 2)
    ax2.imshow(img2)
    ax2.set_title(f"📷 Camera 2  |  Frame {frame_no}", color="white", fontsize=11)
    ax2.axis("off")

    ax3 = fig.add_subplot(1, 3, 3, projection="3d")
    ax3.set_facecolor("#0f172a")
    for i, j in SKELETON:
        if pts[i] and pts[j]:
            ax3.plot([pts[i][0],pts[j][0]], [pts[i][1],pts[j][1]],
                     [pts[i][2],pts[j][2]], color="#38bdf8", lw=2.5)
    for p in pts:
        if p: ax3.scatter(*p, color="#f87171", s=35)
    if bat:
        ax3.scatter(*bat, color="#fbbf24", s=120, marker="*", label="Bat")
        ax3.legend(facecolor="#111827", labelcolor="white", edgecolor="gray")

    ax3.set_xlim(MID_X-AXIS_RANGE, MID_X+AXIS_RANGE)
    ax3.set_ylim(MID_Y-AXIS_RANGE, MID_Y+AXIS_RANGE)
    ax3.set_zlim(MID_Z-AXIS_RANGE, MID_Z+AXIS_RANGE)
    ax3.set_xlabel("X [m]", color="gray"); ax3.set_ylabel("Y [m]", color="gray")
    ax3.set_zlabel("Z [m]", color="gray"); ax3.tick_params(colors="gray")
    ax3.set_title("🏃 3D Skeleton", color="white", fontsize=11)
    ax3.view_init(elev=VIEW_ELEV, azim=VIEW_AZIM)

    plt.tight_layout(pad=0.5)
    display(fig); plt.close(fig)

# ============================================================
# スライダー UI
# ============================================================
slider = widgets.IntSlider(
    value=0, min=0, max=len(frame_list)-1, step=1,
    description="フレーム:", continuous_update=False,
    layout=widgets.Layout(width="90%"),
    style={"description_width": "80px"})

label = widgets.HTML(
    value=f'<b style="color:#38bdf8;font-size:14px;">Frame: {frame_list[0]}</b>')

def on_change(change):
    idx = change["new"]
    label.value = f'<b style="color:#38bdf8;font-size:14px;">Frame: {frame_list[idx]}</b>'
    show_frame(idx)

slider.observe(on_change, names="value")
display(widgets.VBox([widgets.HBox([slider, label])]))
show_frame(0)
```

---

## 実行順序

| セル | 内容 | 目安時間 |
|------|------|---------|
| セル1 | パッケージインストール | 1分 |
| セル2 | ライブラリ・設定 | 即時 |
| セル3 | ステレオキャリブレーション | 1〜2分 |
| セル4 | 三角測量 + CSV出力 | 5〜15分 |
| セル5 | スケール確認 | 即時 |
| セル6 | スライダー可視化 | 即時 |

## チェックポイント

- **セル3 終了後**：`ステレオRMS: X.XX px` → **2.0px 以下**が正常
- **セル5 終了後**：`肩幅: X.XX m` → **0.30〜0.45m**が正常
- **セル6**：スライダーを動かして3画面が同期することを確認
