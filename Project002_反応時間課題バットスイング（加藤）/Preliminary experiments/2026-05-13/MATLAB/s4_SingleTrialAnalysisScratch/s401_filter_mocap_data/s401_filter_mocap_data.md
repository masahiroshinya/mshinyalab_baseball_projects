# s401: モーションキャプチャデータへのローパスフィルター適用

# s401: Low-Pass Filtering of Motion Capture Data

---

## 学習手順 / Learning Flow

| ステップ | ファイル                              | 内容                                                 |
| -------- | ------------------------------------- | ---------------------------------------------------- |
| 1        | `s401a_demo_frequency_components.m` | 周波数成分・パワースペクトルとは何かを確認する       |
| 2        | `s401b_app_butterworth_filter.m`    | fc・order を変えてフィルター特性を対話的に確認する   |
| 3        | `s401_filter_mocap_data.m`          | 実際の SampleData にフィルターを適用するコードを書く |

---

## 目的 / Purpose

モーションキャプチャで計測されたマーカー座標データには、電気的ノイズや反射マーカーの微小な振動に由来する高周波ノイズが含まれる。バターワースローパスフィルターを適用することで、高周波ノイズを除去し、本来の身体運動の軌跡を抽出する。

Motion capture marker data contains high-frequency noise due to electrical noise and minor vibrations of the reflective markers.
Applying a Butterworth low-pass filter removes this noise and extracts the true trajectory of body movement.

## 信号の周波数成分 / Frequency Components of a Signal

### 周波数成分とは？ / What are Frequency Components?

任意の信号は、異なる周波数・振幅をもつ正弦波の重ね合わせで表現できる（フーリエ理論）。
モーションキャプチャのマーカー軌跡は、ゆっくりした身体運動（低周波）と細かな振動・ノイズ（高周波）が合わさった信号である。

Any signal can be represented as a sum of sine waves at different frequencies and amplitudes (Fourier theory).
A motion capture marker trajectory is a combination of slow body movement (low frequency) and fine vibrations/noise (high frequency).

### パワースペクトル / Power Spectrum

FFT（高速フーリエ変換）を使うと、信号を「どの周波数成分がどのくらい含まれているか」を示すパワースペクトルに変換できる。
横軸が周波数 [Hz]、縦軸がその周波数の強さ（パワー）を表す。

FFT (Fast Fourier Transform) converts a signal into a power spectrum showing how much of each frequency is present.
The horizontal axis shows frequency [Hz] and the vertical axis shows the power at each frequency.

### 高周波ノイズの具体例 / Examples of High-Frequency Noise

- 反射マーカーの微小な振動（50 Hz 以上）
  Micro-vibrations of reflective markers (above 50 Hz)
- 計測機器の電気的ノイズ
  Electrical noise from measurement equipment

### 低周波ノイズの具体例 / Examples of Low-Frequency Noise

- マーカーの長時間ドリフト（1 Hz 以下）
  Long-term drift of markers (below 1 Hz)
- 体幹のゆっくりした姿勢変化
  Slow postural changes of the trunk

---

## Step 1: `s401a_demo_frequency_components.m` — デモ実行と確認

### 実行前の準備

MATLABのカレントフォルダを `s401_filter_mocap_data/` に設定してから実行する。

### 表示される Figure の構成

**Figure 1 — 3種類の成分の比較（左列: 時間領域、右列: 周波数領域）**

| 行  | 信号の種類                      | 特徴                                           |
| --- | ------------------------------- | ---------------------------------------------- |
| 1行 | 身体運動成分（3 Hz 正弦波, 青） | パワースペクトルに3 Hz の鋭いピークが1本       |
| 2行 | ハムノイズ（50 Hz 正弦波, 赤）  | パワースペクトルに50 Hz の鋭いピークが1本      |
| 3行 | ランダムノイズ（randn, グレー） | パワーが全周波数帯域に広く分布する（白色雑音） |

**Figure 2 — 合成信号のノイズタイプ別比較**

| 行  | 合成信号                                        | パワースペクトルで見えるもの                 |
| --- | ----------------------------------------------- | -------------------------------------------- |
| 1行 | 運動 + 50 Hz ハムノイズ                         | 3 Hz と 50 Hz に2本の鋭いピーク              |
| 2行 | 運動 + ランダムノイズ（実際のモーキャプに近い） | 3 Hz に1本のピーク＋全帯域にフラットなパワー |

### 確認ポイント（必ず自分の目で確認すること）

**Figure 1 で確認する**

- [X] 身体運動成分（青）のパワースペクトルを見る。3 Hz にだけ鋭いピークが現れているか？
- [X] ハムノイズ（赤）のパワースペクトルを見る。50 Hz にだけ鋭いピークが現れているか？
- [X] ランダムノイズ（グレー）のパワースペクトルを見る。特定の周波数に集中せず、全帯域に広がっているか？
- [X] 時間波形だけを見ると、ハムノイズとランダムノイズはどちらも「ノイズが乗っている」ように見えるが、パワースペクトルではまったく異なる分布になることを確認する。

**Figure 2 で確認する**

- [X] 運動 + ランダムノイズ（下の行）のパワースペクトルが、実際のモーキャプデータに近いことを確認する。
- [X] 実際のモーキャプノイズは「特定の周波数に集中しない」こと＝ 50 Hz 正弦波ではなく、ランダムノイズ（白色雑音）に近いことを理解する。

**Commandウィンドウに表示されるメッセージも読む**

スクリプト実行後、Commandウィンドウに確認ポイントが表示される。内容を読んで、Figureの見え方と一致しているか確認する。

### この Step で理解すべきこと

> **身体運動成分は低周波、ノイズは高周波（広帯域）に分布している。**
> したがって、高周波成分を除去するローパスフィルターをかければ、ノイズを取り除きながら身体運動の軌跡を抽出できる。

---

## Step 2: `s401b_app_butterworth_filter.m` — インタラクティブアプリで確認

### 実行方法

```matlab
>> s401b_app_butterworth_filter
```

### アプリの画面構成

| 領域     | 表示内容                                                                     |
| -------- | ---------------------------------------------------------------------------- |
| 左パネル | fc スライダー（1〜90 Hz）、order スライダー（1〜8）                          |
| 上グラフ | フィルターの周波数応答（ゲイン特性）。縦軸 gain = 1 が「通過」、0 が「除去」 |
| 下グラフ | 合成信号（3 Hz 運動 + 50 Hz 正弦波ノイズ）へのフィルター適用前後の比較       |

上グラフの見方:

- **赤破線** = カットオフ周波数 fc の位置
- **黒点線** = -3 dB ライン（gain = 1/√2 ≈ 0.707）。fc はこのラインと交差する点で定義される
- **青点線** = 3 Hz（身体運動成分）の位置
- **赤点線** = 50 Hz（ノイズ成分）の位置

### 操作手順と確認ポイント

スライダーを動かすたびに、グラフがリアルタイムで更新される。以下の順番で操作して確認する。

**操作 1: fc = 3 Hz まで下げてみる**

- [X] 上グラフで、3 Hz の青点線がすでにゲインが下がり始めている領域に入ることを確認する。
- [X] 下グラフで、フィルター後の信号（青線）が元の3 Hz 運動成分よりも振幅が小さくなることを確認する。

- → **fc を下げすぎると、身体運動成分まで削られてしまう** ことを理解する。

**操作 2: fc = 90 Hz まで上げてみる**

- [X] 上グラフで、50 Hz の赤点線が gain ≈ 1 の領域に入ることを確認する。
- [X] 下グラフで、フィルター後の信号が Raw とほぼ同じになる（ノイズが除去されない）ことを確認する。

- → **fc を上げすぎると、ノイズが残ってしまう** ことを理解する。

**操作 3: fc = 30 Hz、order = 2（デフォルト）に設定する**

- [X] 上グラフで、3 Hz（青点線）が gain ≈ 1 の通過域、50 Hz（赤点線）が gain ≈ 0 の減衰域にあることを確認する。
- [X] 下グラフで、50 Hz 成分が除去され、3 Hz の身体運動がきれいに残ることを確認する。

- → **fc = 30 Hz が、身体運動を保ちつつノイズを除去できる妥当な値** であることを理解する。

**操作 4: fc = 30 Hz に固定したまま order を 1 → 8 まで変えてみる**

- [X] order が高いほど、カットオフ周波数付近のゲイン変化が急峻（シャープ）になることを確認する。
- [X] order = 7 や 8 のとき、下グラフの信号波形に**リンギング（波打ち）** が生じることを確認する。

- → **次数が高すぎると、フィルター処理による人工的な波形歪みが生じる** ことを理解する。

**操作 5: -3 dB ラインの意味を確認する**

- [X] 上グラフの黒点線（gain = 1/√2）と赤破線（fc）の交点を確認する。
- [X] fc を変えても、常にカットオフ周波数でゲインが 1/√2 になることを確認する。

- → **カットオフ周波数は「信号パワーが半分（-3 dB）になる周波数」として定義される** ことを理解する。

### この Step で理解すべきこと

> **fc は「身体運動の最高周波数よりは高く、ノイズ帯域よりは低い」値に設定する。**
> **order は 2〜4 が一般的。高くすると急峻だが、リンギングのリスクがある。**

---

## バターワースフィルター / Butterworth Filter

バターワースフィルターは、通過帯域が最大限に平坦になるように設計されたフィルターである。
生体力学分野のモーションキャプチャデータ処理において広く使用される標準的な手法の一つ。

A Butterworth filter is designed to have a maximally flat magnitude response in the passband.
It is one of the standard methods widely used in biomechanics for processing motion capture data.

### パラメータ / Parameters

**カットオフ周波数 `fc` [Hz]**
この周波数を境に、低周波成分を通過させ、高周波成分を減衰させる。
`fc` より低い周波数は通過（gain ≈ 1）、高い周波数は減衰（gain → 0）する。
At this frequency, low-frequency components pass through and high-frequency components are attenuated.
Frequencies below `fc` pass through (gain ≈ 1); frequencies above are attenuated (gain → 0).

**フィルター次数 `order`**
次数が高いほど、カットオフ周波数付近での減衰が急峻になる（より理想的なフィルター）。
ただし、次数を上げすぎるとリンギング（波打ち）が生じる場合がある。
Higher order = steeper roll-off near fc. However, very high order may cause ringing artifacts.

### ゼロ位相フィルタリング / Zero-Phase Filtering (`filtfilt`)

MATLABの `filtfilt()` は、データに対して順方向と逆方向の2回フィルタリングを行う。
これにより、フィルタリングによる**位相遅れをゼロ**にできる。速度・加速度計算を正確に行うために重要。

MATLAB's `filtfilt()` applies filtering twice: forward and backward.
This results in **zero phase delay**, which is critical for accurate velocity and acceleration calculations.

---

## MATLABでの実装 / Implementation in MATLAB

```matlab
fs = 200 ;       % サンプリング周波数 [Hz] / Sampling frequency [Hz]
fc = 30 ;        % カットオフ周波数 [Hz] / Cutoff frequency [Hz]
order = 2 ;      % フィルター次数 / Filter order

% フィルター係数の設計 / Design filter coefficients
[b, a] = butter(order, fc/(fs/2), 'low') ;

% ゼロ位相フィルタリング / Zero-phase filtering
signal_filt = filtfilt(b, a, signal) ;

% Markers 構造体の全フィールドに適用 / Apply to all fields of Markers struct
Markers_filt = filt_all_fields(b, a, Markers) ;
```

## パラメータ / Parameters

| パラメータ                | 値     | 説明                                                                   |
| ------------------------- | ------ | ---------------------------------------------------------------------- |
| サンプリング周波数 `fs` | 200 Hz | Qualisys の計測設定値 / Qualisys capture frame rate                    |
| カットオフ周波数 `fc`   | 30 Hz  | これ以上の高周波成分を除去する / Frequencies above this are attenuated |
| フィルター次数 `order`  | 2      | 次数が高いほど急峻な減衰特性 / Higher order = steeper roll-off         |

## 使用する関数 / Functions Used

| 関数                               | 説明                                                                       |
| ---------------------------------- | -------------------------------------------------------------------------- |
| `butter(order, Wn)`              | バターワースフィルター係数 `b`, `a` を設計する                         |
| `filtfilt(b, a, x)`              | ゼロ位相フィルタリングを適用する                                           |
| `filt_all_fields(b, a, Markers)` | `Markers` 構造体の全フィールドに `filtfilt` を一括適用する（独自関数） |

## 実行方法 / How to Run

1. MATLABのカレントフォルダを `s401_filter_mocap_data/` に設定する
   Set MATLAB current folder to `s401_filter_mocap_data/`
2. ステップ 1 → 2 → 3 の順でスクリプトを実行する
   Run scripts in order: Step 1 → 2 → 3
3. 最後に `s401_filter_mocap_data.m` で SampleData にフィルターを適用する
   Finally, apply the filter to SampleData in `s401_filter_mocap_data.m`
