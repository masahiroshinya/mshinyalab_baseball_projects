# Step09 実装ステップ3：3D スティックフィギュア可視化（スライダー同期）

作成日：2026-05-18  
担当：山藤プロジェクト（進矢研究室）

---

## やること

`batting_3d_tracking.csv`（実装ステップ2の出力）と同期済み動画を使い、  
以下の **3画面をスライダーで同期表示** する。

```
[ Camera 1 映像 ] | [ Camera 2 映像 ] | [ 3D スティックフィギュア ]
```

スライダーを動かすと、3画面が同時にそのフレームに切り替わる。

---

## 入力ファイル（Colab にアップロードしておくこと）

| ファイル | 説明 |
|---------|------|
| `cam1_synced.mp4` | ソフト1 の出力（同期済み） |
| `cam2_synced.mp4` | ソフト1 の出力（同期済み） |
| `batting_3d_tracking.csv` | 実装ステップ2 の出力（3D座標） |

---

## セル 1：パッケージインストール

```python
!pip install opencv-python-headless pandas numpy matplotlib ipywidgets -q
```

---

## セル 2：設定

```python
# ============================================================
# パスの設定（ここだけ変更すればOK）
# ============================================================
VIDEO1_PATH = "/content/cam1_synced.mp4"          #@param {type:"string"}
VIDEO2_PATH = "/content/cam2_synced.mp4"          #@param {type:"string"}
CSV_3D_PATH = "/content/batting_3d_tracking.csv"  #@param {type:"string"}

# 3D表示パラメータ
AXIS_RANGE = 1.0   #@param {type:"number"}   # 3D軸の表示範囲 ±[m]（広い場合は1.5など）
VIEW_ELEV  = 15    #@param {type:"number"}   # 仰角（真上=90、横=0）
VIEW_AZIM  = -80   #@param {type:"number"}   # 方位角（横から見る角度）
```

---

## セル 3：初期化とデータ読み込み

```python
import cv2
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import ipywidgets as widgets
from IPython.display import display, clear_output

# --------------------------------------------------
# COCOフォーマット 17点 キーポイント定義
# --------------------------------------------------
KP_NAMES = [
    "nose",          # 0
    "left_eye",      # 1
    "right_eye",     # 2
    "left_ear",      # 3
    "right_ear",     # 4
    "left_shoulder", # 5
    "right_shoulder",# 6
    "left_elbow",    # 7
    "right_elbow",   # 8
    "left_wrist",    # 9
    "right_wrist",   # 10
    "left_hip",      # 11
    "right_hip",     # 12
    "left_knee",     # 13
    "right_knee",    # 14
    "left_ankle",    # 15
    "right_ankle",   # 16
]

# 骨格の接続（インデックスのペア）
SKELETON = [
    (0, 1), (0, 2),          # 鼻 → 目
    (1, 3), (2, 4),          # 目 → 耳
    (5, 6),                  # 左肩 ↔ 右肩
    (5, 7), (7, 9),          # 左腕
    (6, 8), (8, 10),         # 右腕
    (5, 11), (6, 12),        # 肩 → 腰
    (11, 12),                # 左腰 ↔ 右腰
    (11, 13), (13, 15),      # 左脚
    (12, 14), (14, 16),      # 右脚
]

# --------------------------------------------------
# CSV 読み込み・有効フレーム抽出
# --------------------------------------------------
df = pd.read_csv(CSV_3D_PATH)

# nose_X が数値として存在する行だけを使う
valid = pd.to_numeric(df["nose_X"], errors="coerce").notna()
df_valid = df[valid].copy().reset_index(drop=True)
frame_list = df_valid["frame_number"].astype(int).tolist()

print(f"✅ 有効フレーム数: {len(frame_list)}")
print(f"   フレーム範囲  : {frame_list[0]} 〜 {frame_list[-1]}")

# --------------------------------------------------
# 全フレームの3D座標範囲を事前計算（軸スケール固定）
# --------------------------------------------------
all_x, all_y, all_z = [], [], []
for kp in KP_NAMES:
    for col, lst in [(f"{kp}_X", all_x), (f"{kp}_Y", all_y), (f"{kp}_Z", all_z)]:
        if col in df_valid.columns:
            vals = pd.to_numeric(df_valid[col], errors="coerce").dropna()
            lst.extend(vals.tolist())

MID_X = float(np.mean(all_x)) if all_x else 0.0
MID_Y = float(np.mean(all_y)) if all_y else 0.0
MID_Z = float(np.mean(all_z)) if all_z else 0.0
print(f"   3D重心 → X:{MID_X:.3f}  Y:{MID_Y:.3f}  Z:{MID_Z:.3f} [m]")

# --------------------------------------------------
# 動画キャプチャの初期化
# --------------------------------------------------
cap1 = cv2.VideoCapture(VIDEO1_PATH)
cap2 = cv2.VideoCapture(VIDEO2_PATH)

def read_frame(cap, frame_no):
    """指定フレームのRGB画像を返す。失敗時は黒画像。"""
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
    ok, img = cap.read()
    if ok:
        return cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    return np.zeros((480, 640, 3), dtype=np.uint8)

def get_kps(row):
    """DataFrameの1行から17点の3D座標を取得。無効点はNone。"""
    pts = []
    for kp in KP_NAMES:
        x = pd.to_numeric(row.get(f"{kp}_X", np.nan), errors="coerce")
        y = pd.to_numeric(row.get(f"{kp}_Y", np.nan), errors="coerce")
        z = pd.to_numeric(row.get(f"{kp}_Z", np.nan), errors="coerce")
        pts.append(None if any(np.isnan([x, y, z])) else (float(x), float(y), float(z)))
    return pts

print("✅ 初期化完了。次のセルを実行してください。")
```

---

## セル 4：スライダー付き3面同期ビューア

```python
# ============================================================
# 描画関数
# ============================================================
def show_frame(frame_idx):
    """スライダー値が変わるたびに呼ばれる。3画面を同時更新。"""
    clear_output(wait=True)          # 前の描画を消す（ちらつき防止）
    frame_no = frame_list[frame_idx]

    # ---- データ取得 ----
    row   = df_valid[df_valid["frame_number"] == frame_no].iloc[0]
    img1  = read_frame(cap1, frame_no)
    img2  = read_frame(cap2, frame_no)
    pts   = get_kps(row)

    bat = None
    if "bat_X" in row.index and pd.notna(row["bat_X"]):
        bat = (float(row["bat_X"]), float(row["bat_Y"]), float(row["bat_Z"]))

    # ---- 描画レイアウト（1行3列） ----
    fig = plt.figure(figsize=(18, 6))
    fig.patch.set_facecolor("#111827")

    # ── 左：Camera 1 ──────────────────────────────
    ax1 = fig.add_subplot(1, 3, 1)
    ax1.imshow(img1)
    ax1.set_title(f"📷  Camera 1  |  Frame {frame_no}",
                  color="white", fontsize=12, pad=6)
    ax1.axis("off")

    # ── 中：Camera 2 ──────────────────────────────
    ax2 = fig.add_subplot(1, 3, 2)
    ax2.imshow(img2)
    ax2.set_title(f"📷  Camera 2  |  Frame {frame_no}",
                  color="white", fontsize=12, pad=6)
    ax2.axis("off")

    # ── 右：3D スティックフィギュア ───────────────
    ax3 = fig.add_subplot(1, 3, 3, projection="3d")
    ax3.set_facecolor("#0f172a")

    # 骨格リンク（水色の線）
    for i, j in SKELETON:
        if pts[i] and pts[j]:
            ax3.plot(
                [pts[i][0], pts[j][0]],
                [pts[i][1], pts[j][1]],
                [pts[i][2], pts[j][2]],
                color="#38bdf8", linewidth=2.5, alpha=0.9
            )

    # 関節点（赤い丸）
    for p in pts:
        if p:
            ax3.scatter(*p, color="#f87171", s=35, zorder=5)

    # バット中心（金色の星）
    if bat:
        ax3.scatter(*bat, color="#fbbf24", s=120, marker="*",
                    zorder=6, label="Bat")
        ax3.legend(loc="upper right", fontsize=8,
                   labelcolor="white", facecolor="#111827", edgecolor="gray")

    # 軸スケール固定（全フレーム共通）
    ax3.set_xlim(MID_X - AXIS_RANGE, MID_X + AXIS_RANGE)
    ax3.set_ylim(MID_Y - AXIS_RANGE, MID_Y + AXIS_RANGE)
    ax3.set_zlim(MID_Z - AXIS_RANGE, MID_Z + AXIS_RANGE)
    ax3.set_xlabel("X [m]", color="gray", fontsize=9)
    ax3.set_ylabel("Y [m]", color="gray", fontsize=9)
    ax3.set_zlabel("Z [m]", color="gray", fontsize=9)
    ax3.tick_params(colors="gray", labelsize=7)
    ax3.set_title("🏃  3D Skeleton", color="white", fontsize=12, pad=6)
    ax3.view_init(elev=VIEW_ELEV, azim=VIEW_AZIM)

    plt.tight_layout(pad=0.5)
    display(fig)
    plt.close(fig)    # メモリ解放


# ============================================================
# スライダー UI
# ============================================================
slider = widgets.IntSlider(
    value=0,
    min=0,
    max=len(frame_list) - 1,
    step=1,
    description="フレーム:",
    continuous_update=False,        # ドラッグ中は更新しない（重い処理向け）
    layout=widgets.Layout(width="90%"),
    style={"description_width": "80px"},
)

label = widgets.HTML(
    value=f'<b style="color:#38bdf8;font-size:14px;">Frame No: {frame_list[0]}</b>'
)

def on_change(change):
    idx = change["new"]
    label.value = (
        f'<b style="color:#38bdf8;font-size:14px;">'
        f'Frame No: {frame_list[idx]}</b>'
    )
    show_frame(idx)

slider.observe(on_change, names="value")

# 初期表示
display(widgets.VBox([widgets.HBox([slider, label])]))
show_frame(0)
```

---

## 表示調整のヒント

| パラメータ | 説明 | 目安 |
|-----------|------|------|
| `AXIS_RANGE` | 3D軸の範囲 ±[m] | 体が小さければ `1.5`〜`2.0` に |
| `VIEW_ELEV` | 仰角（上から見る度合い） | `15`（斜め上）〜`30` |
| `VIEW_AZIM` | 方位角（左右の向き） | `-90`（真横）〜`-60` |
| `continuous_update=False` | ドラッグ中は更新しない | 処理が遅い場合はこのまま |

---

## よくあるエラーと対処

| エラー | 原因 | 対処 |
|--------|------|------|
| `cap1` が動画を読めない | ファイルパスが違う | `VIDEO1_PATH` を確認 |
| 3Dが何も表示されない | CSV の `nose_X` が全部 NaN | 実装ステップ2を再実行 |
| スライダーが動かない | セル3が未実行 | セル3から再実行 |
| メモリ不足 | figsize が大きすぎ | `figsize=(14, 5)` に縮小 |
