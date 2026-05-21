# ソフト1（音声版）：音声クロスコリレーションによる映像同期

## 概要と手法選択の理由

### なぜ音声クロスコリレーションか

| 手法 | 精度 | 手間 | 問題点 |
|:---|:---|:---|:---|
| LED輝度（従来） | ±1フレーム理論値 | ROI指定が必要 | パルス誤検出により大きくずれる（worklist.md TODO参照） |
| **音声クロスコリレーション（本手法）** | **±1フレーム相当** | **不要（全自動）** | 無音環境では精度低下 |
| 尺合わせ（簡易版） | ±数秒 | 不要 | 末尾が揃っている前提 |

### 原理

録画中に発生した**共通の音（手拍子・声・ボールの打撃音など）**がすべてのカメラのマイクに記録される。  
各カメラの音声波形をクロスコリレーションすると、2つの波形が最も重なり合うラグ（遅延量）が求められる。  
そのラグを音声サンプル数 → フレーム数に変換し、映像クリップの開始位置を決定する。

```
Cam1 音声: ──────[手拍子]──────────────────
Cam2 音声: ──[手拍子]──────────────────────
                ↑
          Cam2 が L サンプル早く録音開始
→ Cam2 の先頭 L サンプル分（= Lf フレーム分）を削る
```

### OSMO Action 3 の仕様前提

| 項目 | 仕様 |
|:---|:---|
| 動画フレームレート | 239.76 fps (≈ 240 fps) |
| 音声サンプリングレート | 48,000 Hz（1フレーム = 200.2 サンプル） |
| 音声チャンネル | ステレオ → モノラルに変換して処理 |
| コンテナ | MP4（音声コーデック: AAC） |

> **撮影時の推奨:** 録画開始直後に**手拍子を1〜3回**打つ。  
> 複数回・ランダム間隔で打つとクロスコリレーションのピークが明確になり精度が上がる。

---

## 🎓 初学者向け：音声同期の仕組みをゼロから理解する

> このセクションは「音声クロスコリレーションとは何か」を、数式なしで直感的に理解するための解説です。  
> 「仕組みはいいからコードだけ見たい」という場合はスキップして [作業ステップ一覧](#作業ステップ一覧) へ。

---

### STEP 0：音とは何か（数字の列として考える）

マイクで録音した音は、コンピュータの中では**数字の列**として保存されています。

```
時刻:     0     1     2     3     4     5     6  ...（単位: サンプル）
Cam1音声: 0.01  0.02  0.80  0.85  0.70  0.02  0.01  ...
                      ↑
                  手拍子の瞬間（大きな値になる）
```

OSMO Action 3 の音声は **1秒間に48,000個**の数字が並びます（48,000 Hz）。  
つまり手拍子1回分の音は、数千個の数字の山として記録されます。

---

### STEP 1：なぜ2台のカメラの音声がズレるのか

2台のカメラを**別々のタイミングでスタートボタンを押した**場合、それぞれ「録音開始時刻」が異なります。

```
実際の時刻軸:  |===0秒===|===5秒===|===10秒==|===15秒==|
                    ↑                    ↑
               Cam1 録画開始          Cam2 録画開始

Cam1の音声ファイル（内部の時刻）:
  [0秒] ─────────────────────── [90秒]
             ↑ 手拍子（実際の時刻10秒 → Cam1内では10秒目）

Cam2の音声ファイル（内部の時刻）:
  [0秒] ─────────────────── [80秒]
      ↑ 手拍子（実際の時刻10秒 → Cam2内では5秒目）
```

**同じ「手拍子」の音が、Cam1の中では10秒目、Cam2の中では5秒目に記録されています。**  
→ 2つのファイルを頭から同時に再生すると、**5秒分ずれて見える**のはこのためです。

---

### STEP 2：クロスコリレーションとは「ずらして重ねる操作」

**クロスコリレーション**とは、2つの音声波形の**片方をスライドさせながら、どれだけ似ているかを全パターン測る**操作です。

#### アナロジー（透かし紙）

> 同じ絵が描かれた**2枚の透かし紙**を重ね、片方をずらしながら「どの位置で絵が一番ピッタリ重なるか」を探す。  
> → 絵が完全に重なったときの**ずらし量 = 2台カメラの録音開始時刻のズレ**

```
Cam1波形（固定）:  ___/\___/\/\___/\___
Cam2波形（ずらす）:

  ずらし量 -3秒:  ___/\___/\/\___  （全然合わない → 相関値: 低い）
  ずらし量 -1秒:    _/\___/\/\___  （少し合う   → 相関値: 中）
  ずらし量  0秒:  ___/\___/\/\___  （ズレたまま → 相関値: 低）
  ずらし量 +5秒:  _____/\___/\/\_ （ピッタリ！ → 相関値: 最大）← ここが答え

                                       ↑
                              「ずらし量 = +5秒」= オフセット
```

プログラムは、全てのずらし量（マイナスからプラスまで）で「一致度（相関値）」を計算し、  
**相関値が最大になるずらし量**を自動で見つけます。これが `signal.correlate()` の仕事です。

---

### STEP 3：相関値グラフの読み方

`compute_audio_offset()` を実行すると、以下のようなグラフが表示されます。

```
相関値
  ↑
  |                 ★ ← ここが「最もピッタリ重なるずらし量」
  |                /|\
  |               / | \
  |______________/  |  \__________________
  +─────────────────────────────────────→ ラグ（秒）
  -60秒    -30秒    0秒    +30秒    +60秒
                         ↑
                    Cam2が遅れている
```

- **ピークが右側（正の値）** → Cam2 は Cam1 より「遅く」録画を開始した
- **ピークが左側（負の値）** → Cam2 は Cam1 より「早く」録画を開始した
- **ピークが0付近**         → ほぼ同時にスタートした

---

### STEP 4：サンプル数 → 秒 → フレーム数への変換

クロスコリレーションの結果は「**何サンプル分のズレか**」という形で得られます。  
これを映像のフレーム数に変換する必要があります。

```
オフセット（サンプル数）
        ÷ 48,000  →  オフセット（秒）
        × 239.76  →  オフセット（フレーム数）  ← 映像クリップに使う値
```

#### 具体例（上記のシナリオで）

```
クロスコリレーションのピーク: +240,000 サンプル
÷ 48,000 Hz → +5.000 秒
× 239.76 fps → +1,199 フレーム

→ Cam2 は Cam1 より 5秒 = 約1,199フレーム 遅く録画開始
```

---

### STEP 5：どちらの映像を、何フレーム削るか

ズレが分かったら、**「最も遅く録画を開始したカメラ」に全員を合わせる**ことで同期します。

```
「最も遅く始まったカメラ」= 映像ファイルの中で、共通イベント（手拍子）が
                           最も早い時刻に現れるカメラ
```

#### 具体例

```
Cam1: 手拍子が 10秒目 に収録（10秒分の助走がある）
Cam2: 手拍子が  5秒目 に収録（5秒分の助走がある）

→ Cam1 の方が助走が長い = Cam1 の先頭を多く削る
→ Cam2 の先頭も削るが、Cam1 ほどは削らない

計算式:
  skip_cam1 = max(offset_cam1, offset_cam2) - offset_cam1
             = max(10秒, 5秒) - 10秒 = 0秒  → Cam1 は削らない
  skip_cam2 = max(offset_cam1, offset_cam2) - offset_cam2
             = max(10秒, 5秒) -  5秒 = 5秒  → Cam2 の先頭 5秒を削る
```

> **ポイント：** 「最も遅く始まったカメラ（助走が最も短いカメラ）」はスキップ量が 0 になります。  
> 他のカメラは「その差分だけ先頭を削る」ので、全員が**同じ絶対時刻から始まる映像**になります。

```
削る前:
  Cam1: [──────────────────────────────────] 90秒
                    ↑10秒目 手拍子
  Cam2: [────────────────────────────] 80秒
              ↑5秒目 手拍子

削った後（同期済み）:
  Cam1: [────────────────────────────────] 80秒 ← 先頭10秒を削除
                ↑0秒目（=元の10秒目）
  Cam2: [─────────────────────────────────] 75秒 ← 先頭5秒を削除
                ↑0秒目（=元の5秒目）

  → さらに短い方（75秒）に統一して両方を切り出す
  → 出力: cam1_synced.mp4 と cam2_synced.mp4（どちらも75秒・同じフレーム数）
```

---

### まとめ：処理の全体フロー

```
① MP4から音声を抽出 (ffmpeg)
   └→ 48,000Hz のモノラル WAV ファイル

② 両カメラの音声を正規化
   └→ 音量の大小に依存しないよう、振れ幅を揃える

③ クロスコリレーションを計算 (scipy.signal.correlate)
   └→ 全てのずらし量で「一致度」を計算（数百万パターン）

④ 一致度が最大になるずらし量（ラグ）を取得
   └→ 単位: サンプル数

⑤ 単位変換
   └→ サンプル数 ÷ 48000 = 秒 → 秒 × 239.76 = フレーム数

⑥ 各カメラの先頭スキップ量を計算
   └→ 最も遅いカメラに合わせる

⑦ 映像をクリップして保存 (OpenCV)
   └→ cam1_synced.mp4, cam2_synced.mp4
```

---

### よくある疑問

**Q: なぜ音声で映像を同期できるの？**  
A: 音声と映像は同じタイムラインに記録されているため、「音声のズレ量」＝「映像のズレ量」です。  
   音声は48,000Hz（1秒48,000点）なので、映像フレーム（240fps = 1秒240枚）より**200倍細かい時間分解能**があります。

**Q: 手拍子以外でも使える？**  
A: はい。バット打撃音・声・扉の音など、全カメラに同時に聞こえる**鋭い音（インパルス状）**なら何でも使えます。むしろ普通の環境音（空調・風・話し声）がずっと続いている状態でも、それを「共通信号」として同期できます。

**Q: カメラを同時にスタートすれば不要では？**  
A: 人間の操作では0.1〜1秒のズレが生じます。240fpsでは0.1秒 = 24フレームのズレになるため、音声同期が必要です。

---

## 作業ステップ一覧

| ステップ | 内容 | 所要時間 |
|:---|:---|:---|
| S1-1 | 環境チェックとライブラリ準備 | 1〜2分 |
| S1-2 | 動画情報の取得 | 1分 |
| S1-3 | 音声の抽出（WAV変換） | 1〜3分 |
| S1-4 | 音声クロスコリレーションによるオフセット計算 | 1分 |
| S1-5 | 結果の可視化と確認 | 2〜3分 |
| S1-6 | 映像クリップと保存 | 5〜15分 |
| S1-7 | 同期確認（先頭・末尾フレーム表示） | 2〜3分 |

**合計: 約15〜30分**

---

## 手順 S1-1：環境チェックとライブラリ準備

```python
# ============================================================
# ソフト1（音声版）— S1-1: 環境チェックとライブラリ準備
# ============================================================
import subprocess, sys, os
import numpy as np
import scipy.io.wavfile as wav
from scipy import signal
import matplotlib.pyplot as plt
import cv2

# ffmpeg の存在確認（Colab には標準搭載）
result = subprocess.run(["ffmpeg", "-version"], capture_output=True, text=True)
if result.returncode == 0:
    ver = result.stdout.split("\n")[0]
    print(f"✅ ffmpeg: {ver}")
else:
    print("❌ ffmpeg が見つかりません。以下を実行してください:")
    print("   !apt-get install -y ffmpeg")

print(f"✅ NumPy  : {np.__version__}")
print(f"✅ OpenCV : {cv2.__version__}")
print("✅ ライブラリの準備完了")
```

**確認ポイント：**
- `ffmpeg` のバージョンが表示されること
- エラーが出た場合は `!apt-get install -y ffmpeg` を先に実行する

---

## 手順 S1-2：動画情報の取得

```python
# ============================================================
# ソフト1（音声版）— S1-2: 動画情報の取得
# ============================================================
def get_video_info(path):
    """動画ファイルの基本情報を取得する"""
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        raise FileNotFoundError(f"動画ファイルを開けません: {path}")
    info = {
        "path":     path,
        "fps":      cap.get(cv2.CAP_PROP_FPS),
        "width":    int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
        "height":   int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
        "n_frames": int(cap.get(cv2.CAP_PROP_FRAME_COUNT)),
    }
    info["duration_sec"] = info["n_frames"] / info["fps"] if info["fps"] > 0 else 0
    cap.release()
    return info

# ============================================================
#@title 動画ファイルのパス入力 { display-mode: "form" }
camera1_path = "/content/cam1.MP4"  #@param {type:"string"}
camera2_path = "/content/cam2.MP4"  #@param {type:"string"}
# ============================================================

video_paths = [camera1_path, camera2_path]
video_infos = [get_video_info(p) for p in video_paths]
nCamera = len(video_paths)

print("=== 動画情報 ===")
for i, info in enumerate(video_infos):
    print(f"  Camera {i+1}: FPS={info['fps']:.4f}, "
          f"{info['width']}x{info['height']}, "
          f"{info['n_frames']} frames, "
          f"{info['duration_sec']:.1f} sec")

# FPS 整合チェック
fps_values = [info["fps"] for info in video_infos]
if all(abs(f - fps_values[0]) < 0.1 for f in fps_values):
    print(f"\n✅ FPS 一致: {fps_values[0]:.4f} fps")
    base_fps = fps_values[0]
else:
    print(f"\n⚠ FPS 不一致: {fps_values} — 同期精度に影響する可能性があります")
    base_fps = fps_values[0]

frame_ms = 1000.0 / base_fps
print(f"  1フレーム = {frame_ms:.3f} ms")
```

---

## 手順 S1-3：音声の抽出（WAV変換）

```python
# ============================================================
# ソフト1（音声版）— S1-3: ffmpeg で音声を WAV に抽出
# ============================================================
SAMPLE_RATE = 48000   # OSMO Action 3 の音声サンプリングレート (Hz)

def extract_audio_wav(video_path, out_wav_path, sample_rate=SAMPLE_RATE):
    """
    ffmpeg を使って動画ファイルから音声をモノラル WAV として抽出する。

    Args:
        video_path   : 入力動画ファイルのパス
        out_wav_path : 出力 WAV ファイルのパス
        sample_rate  : 出力サンプリングレート（Hz）

    Returns:
        sr   : サンプリングレート
        data : 音声データ（numpy array, float32 に正規化済み）
    """
    cmd = [
        "ffmpeg", "-y",             # -y: 上書き確認なし
        "-i", video_path,
        "-ac", "1",                 # モノラルに変換
        "-ar", str(sample_rate),    # サンプリングレートを指定
        "-vn",                      # 映像を無視
        "-f", "wav",
        out_wav_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg エラー:\n{result.stderr}")

    sr, data = wav.read(out_wav_path)

    # int16 → float32 に正規化（-1.0 〜 1.0）
    if data.dtype == np.int16:
        data = data.astype(np.float32) / 32768.0
    elif data.dtype == np.int32:
        data = data.astype(np.float32) / 2147483648.0
    else:
        data = data.astype(np.float32)

    return sr, data

# --- 全カメラの音声を抽出 ---
audio_data = []
sample_rates = []

print("=== 音声抽出中... ===")
for i, path in enumerate(video_paths):
    wav_path = f"/content/cam{i+1}_audio.wav"
    print(f"  Camera {i+1}: {path} → {wav_path}")
    sr, data = extract_audio_wav(path, wav_path)
    audio_data.append(data)
    sample_rates.append(sr)
    duration_audio = len(data) / sr
    print(f"    ✅ 抽出完了: {len(data)} samples, {sr} Hz, {duration_audio:.1f} sec")

# サンプリングレート整合チェック
if len(set(sample_rates)) == 1:
    SR = sample_rates[0]
    print(f"\n✅ 全カメラのサンプリングレート一致: {SR} Hz")
    print(f"  1フレームあたりの音声サンプル数: {SR / base_fps:.1f} samples")
else:
    raise ValueError(f"サンプリングレートが異なります: {sample_rates}")
```

**確認ポイント：**
- 各カメラの音声サンプル数 ÷ SR ≈ 動画の秒数 になっていること
- エラーが出た場合はMP4に音声トラックがあるか確認（無音で録画した場合は使用不可）

---

## 手順 S1-4：音声クロスコリレーションによるオフセット計算

```python
# ============================================================
# ソフト1（音声版）— S1-4: クロスコリレーションでオフセット計算
# ============================================================
def compute_audio_offset(audio_ref, audio_target, sr, fps):
    """
    音声クロスコリレーションにより、カメラ間のフレームオフセットを計算する。

    Args:
        audio_ref    : 基準カメラ（Camera 1）の音声データ（float32）
        audio_target : 対象カメラの音声データ（float32）
        sr           : サンプリングレート（Hz）
        fps          : 映像フレームレート

    Returns:
        offset_frames : フレーム単位のオフセット
                        正の値 → target が offset_frames フレーム分「早く」録音開始
                        負の値 → target が |offset_frames| フレーム分「遅く」録音開始
        offset_sec    : オフセットの秒数
        offset_samples: オフセットのサンプル数
        correlation   : クロスコリレーション配列
        lags_samples  : ラグ配列（サンプル単位）
    """
    # 正規化（DC成分除去 + 振幅正規化）
    ref_norm    = (audio_ref    - np.mean(audio_ref))    / (np.std(audio_ref)    + 1e-8)
    target_norm = (audio_target - np.mean(audio_target)) / (np.std(audio_target) + 1e-8)

    # クロスコリレーション計算
    # mode='full': 全てのラグで相関を計算
    # 注意: 長い音声同士の full correlation は非常に時間がかかるため
    #       先頭 60 秒だけを使って計算する（同期イベントは録画開始直後にある前提）
    USE_SEC = 60  # 使用する音声の長さ（秒）
    n_use = min(int(USE_SEC * sr), len(ref_norm), len(target_norm))

    print(f"  クロスコリレーション計算中（先頭 {n_use/sr:.0f} 秒分）...")
    correlation = signal.correlate(ref_norm[:n_use], target_norm[:n_use], mode='full')
    lags_samples = signal.correlation_lags(n_use, n_use, mode='full')

    # ピーク（最大相関）のラグを取得
    peak_idx     = np.argmax(correlation)
    offset_samp  = lags_samples[peak_idx]
    offset_sec   = offset_samp / sr
    offset_frames = int(round(offset_sec * fps))
    peak_corr    = correlation[peak_idx]
    norm_peak    = peak_corr / n_use   # 正規化相関係数（-1〜1）

    return offset_frames, offset_sec, offset_samp, correlation, lags_samples, norm_peak

# --- Camera 1 を基準に全カメラのオフセットを計算 ---
print("=== 音声クロスコリレーション ===")
offsets_frames = [0]   # Camera 1 は基準（オフセット 0）
offsets_sec    = [0.0]

for i in range(1, nCamera):
    off_f, off_s, off_samp, corr, lags, peak = compute_audio_offset(
        audio_data[0], audio_data[i], SR, base_fps
    )
    offsets_frames.append(off_f)
    offsets_sec.append(off_s)

    direction = "早く" if off_f > 0 else "遅く"
    print(f"  Cam1 vs Cam{i+1}:")
    print(f"    オフセット: {off_samp:+d} samples "
          f"= {off_s:+.4f} sec "
          f"= {off_f:+d} frames")
    print(f"    → Cam{i+1} は Cam1 より {abs(off_f)} フレーム {direction} 録音開始")
    print(f"    正規化相関係数: {peak:.4f}  (0.3以上で信頼性あり)")

print(f"\nオフセット一覧（フレーム）: {offsets_frames}")
```

**確認ポイント：**
- 正規化相関係数が **0.3 以上** あること（低い場合は無音区間が長すぎる・マイク感度不足）
- オフセット秒数が「録画開始のタイミングのズレ」として合理的であること（通常 ±数秒〜数十秒）

---

## 手順 S1-5：結果の可視化と確認

```python
# ============================================================
# ソフト1（音声版）— S1-5: 結果の可視化
# ============================================================

# --- 音声波形の全体表示 ---
fig, axes = plt.subplots(nCamera, 1, figsize=(16, 3 * nCamera), sharex=False)
if nCamera == 1: axes = [axes]

for i, data in enumerate(audio_data):
    t = np.arange(len(data)) / SR
    axes[i].plot(t, data, linewidth=0.3, color='steelblue', alpha=0.8)
    axes[i].set_title(f"Camera {i+1} — 音声波形（全体）", fontweight='bold')
    axes[i].set_xlabel("時間 (sec)")
    axes[i].set_ylabel("振幅")
    axes[i].grid(True, alpha=0.3)

plt.suptitle("音声波形 — 共通の音イベント（手拍子等）が見えるか確認", fontsize=13)
plt.tight_layout()
plt.show()

# --- クロスコリレーションのプロット（Cam1 vs Cam2 のみ表示）---
if nCamera >= 2:
    # クロスコリレーションを再計算（可視化用に保持）
    off_f, off_s, off_samp, corr, lags, peak = compute_audio_offset(
        audio_data[0], audio_data[1], SR, base_fps
    )
    lags_sec = lags / SR

    fig, ax = plt.subplots(figsize=(14, 4))
    # 表示範囲を ±120 秒に限定（全体が長すぎる場合）
    mask = np.abs(lags_sec) <= 120
    ax.plot(lags_sec[mask], corr[mask], color='steelblue', linewidth=0.5)
    ax.axvline(x=off_s, color='crimson', linewidth=2,
               label=f"ピーク: {off_s:+.4f} sec ({off_f:+d} frames)")
    ax.axvline(x=0, color='gray', linewidth=1, linestyle='--', label='ラグ 0')
    ax.set_title("クロスコリレーション（Cam1 vs Cam2）", fontweight='bold')
    ax.set_xlabel("ラグ (sec)  ← Cam2が早い ｜ Cam2が遅い →")
    ax.set_ylabel("相関値")
    ax.legend()
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.show()

    print(f"ピーク位置: {off_s:+.4f} sec = {off_f:+d} frames")
    print(f"解釈: Cam2 は Cam1 より {abs(off_f)} フレーム {'早く' if off_f > 0 else '遅く'} 録音開始")
```

**確認ポイント：**
- クロスコリレーションに **明確な1つのピーク** があること
- 複数のピークが同程度の高さで並んでいる場合は、手拍子が等間隔すぎる可能性あり

---

## 手順 S1-6：映像クリップと保存

```python
# ============================================================
# ソフト1（音声版）— S1-6: 開始フレームの決定とクリップ保存
# ============================================================
def compute_start_frames(offsets_frames):
    """
    各カメラのオフセットから、映像クリップ開始フレームを計算する。

    ロジック:
        offset[i] = 「Cam_i は Cam1 より offset[i] フレーム早く録音開始」
        → 早く始まった方が多くのフレームを持つ → 先頭を削る

        start_frame[i] = max(0, max(offsets) - offsets[i])
        = 「最も遅く始まったカメラに全員を合わせる」

    Returns:
        start_frames: list[int]
    """
    max_offset = max(offsets_frames)
    start_frames = [max_offset - off for off in offsets_frames]
    return start_frames

start_frames = compute_start_frames(offsets_frames)

print("=== クリップ開始フレームの決定 ===")
for i in range(nCamera):
    skip_sec = start_frames[i] / base_fps
    print(f"  Camera {i+1}: 先頭 {start_frames[i]} frames ({skip_sec:.3f} sec) をスキップ")

# 共通フレーム数
available_frames = [video_infos[i]["n_frames"] - start_frames[i] for i in range(nCamera)]
common_frames = min(available_frames)
print(f"\n  共通フレーム数: {common_frames} frames = {common_frames/base_fps:.1f} sec")

# --- 保存 ---
def clip_and_save(video_paths, start_frames, common_frames, video_infos,
                  output_prefix="cam"):
    """
    各カメラの映像を start_frames[i] からクリップし、common_frames フレーム保存する。
    """
    fps    = video_infos[0]["fps"]
    width  = video_infos[0]["width"]
    height = video_infos[0]["height"]
    fourcc = cv2.VideoWriter_fourcc(*"mp4v")

    output_paths = []
    for i, (path, sf) in enumerate(zip(video_paths, start_frames)):
        out_path = f"{output_prefix}{i+1}_synced.mp4"
        output_paths.append(out_path)

        cap = cv2.VideoCapture(path)
        out = cv2.VideoWriter(out_path, fourcc, fps, (width, height))
        cap.set(cv2.CAP_PROP_POS_FRAMES, sf)

        report_interval = max(1, common_frames // 10)
        print(f"\nCamera {i+1}: Frame {sf} からクリップ開始...")

        for f in range(common_frames):
            ret, frame = cap.read()
            if not ret:
                print(f"  ⚠ Camera {i+1}: Frame {sf + f} で読み込み失敗")
                break
            out.write(frame)
            if (f + 1) % report_interval == 0:
                pct = (f + 1) / common_frames * 100
                print(f"  Camera {i+1}: {pct:.0f}% ({f+1}/{common_frames})")

        cap.release()
        out.release()
        print(f"  ✅ Camera {i+1}: {out_path} を保存しました")

    return output_paths

#@title 出力設定 { display-mode: "form" }
output_prefix = "cam"  #@param {type:"string"}

print("\n=== 映像クリップ・保存開始 ===")
output_paths = clip_and_save(video_paths, start_frames, common_frames,
                             video_infos, output_prefix=output_prefix)
```

---

## 手順 S1-7：同期確認（先頭・末尾フレーム表示）

```python
# ============================================================
# ソフト1（音声版）— S1-7: 同期確認
# ============================================================
import os

print("=== 出力ファイル情報 ===")
for p in output_paths:
    if os.path.exists(p):
        info = get_video_info(p)
        size_mb = os.path.getsize(p) / (1024 * 1024)
        print(f"  {p}: {info['n_frames']} frames, "
              f"{info['duration_sec']:.1f} sec, {size_mb:.1f} MB")

# --- 先頭・末尾フレームの目視確認 ---
check_positions = {
    f"先頭 (Frame 0)":             0,
    f"末尾 (Frame {common_frames - 1})": common_frames - 1,
}
fig, axes = plt.subplots(len(check_positions), nCamera,
                          figsize=(7 * nCamera, 5 * len(check_positions)))

for row, (label, frame_no) in enumerate(check_positions.items()):
    for col, path in enumerate(output_paths):
        cap = cv2.VideoCapture(path)
        cap.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
        ret, frame = cap.read()
        cap.release()
        ax = axes[row][col] if nCamera > 1 else axes[row]
        if ret:
            frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            ax.imshow(cv2.resize(frame_rgb, None, fx=0.3, fy=0.3))
        ax.set_title(f"Cam{col+1} — {label}")
        ax.axis("off")

plt.suptitle(
    "先頭・末尾フレームの比較\n"
    "同じシーンが映っていれば同期成功。ずれていれば S1-5 のクロスコリレーションを再確認。",
    fontsize=12
)
plt.tight_layout()
plt.show()

# --- 同期サマリー ---
print("\n=== 同期サマリー ===")
print(f"{'カメラ':<10} {'スキップ(frames)':<20} {'スキップ(sec)':<15} {'出力フレーム数'}")
print("-" * 60)
for i in range(nCamera):
    print(f"  Cam{i+1}    {start_frames[i]:<20} {start_frames[i]/base_fps:<15.3f} {common_frames}")
print(f"\n  同期後の映像長: {common_frames/base_fps:.2f} sec")
print("\n次のステップ:")
print("  → ソフト2（キャリブレーション画像取得）: cam1_synced.mp4, cam2_synced.mp4 を入力として使用")
```

---

## トラブルシューティング

| 症状 | 原因 | 対処 |
|:---|:---|:---|
| 正規化相関係数が 0.1 以下 | 録画中に共通の音がほぼない | 録画開始直後に手拍子を打って再撮影 |
| クロスコリレーションにピークが複数ある | 手拍子が等間隔（周期性がある） | ランダムな間隔で打ち直す |
| オフセットが ±120 秒を超える | 先頭 60 秒分だけを使用しているため検出できない | `USE_SEC` を 120 等に増やす |
| 先頭フレームの場面がズレている | ピークが局所最大値に引っかかっている | `lags_sec[mask]` の全体プロットを確認し、最大ピークか目視で確認 |
| MP4 に音声トラックがない | カメラ設定でマイクがオフ | カメラ設定を確認 / 代替手法（LED輝度・尺合わせ）を使用 |

---

## 関連ファイル

| ファイル | 内容 |
|:---|:---|
| [実装ステップ.md](./実装ステップ.md) | ソフト1（LED輝度版）・ソフト2・ソフト3 の詳細手順 |
| [簡易ステップ_尺合わせクリップ.md](./簡易ステップ_尺合わせクリップ.md) | 末尾合わせのシンプルなクリップ手法 |
| [worklist.md](./worklist.md) | 保留中のTODO（LED輝度同期のデバッグ等）を含む設計方針書 |
