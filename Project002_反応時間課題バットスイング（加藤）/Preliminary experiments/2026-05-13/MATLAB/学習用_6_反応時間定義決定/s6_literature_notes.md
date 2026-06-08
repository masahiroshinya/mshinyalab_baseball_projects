# 先行研究調査メモ：反応時間の定義

## 文献1：Nasu et al. (2020)

- **著者・年**：Nasu, D., Yamaguchi, M., Kobayashi, A., Saijo, N., Kashino, M., & Kimura, T. (2020)
- **タイトル**：Behavioral Measures in a Cognitive-Motor Batting Task Explain Real Game Performance of Top Athletes
- **掲載誌**：Frontiers in Sports and Active Living, 2, 55
- **DOI**：10.3389/fspor.2020.00055

### 実験概要

- **被験者**：エリート女性ソフトボール打者 17名
- **課題**：2名の投手がランダムに投じる「速球」「遅球」を実際に打つバッティング課題
- **計測機器**：慣性センサー（MVN BIOTECH, Xsens B.V.）、サンプリング周波数 **240 Hz**
- **指標**：速球と遅球に対するスイング開始時刻の差（**デルタオンセット**）

### スイング開始（swing onset）の定義【本研究と直接関連する定義】

| 要素 | 定義の内容 |
|------|-----------|
| **使用マーカー** | 捕手側の**手部セグメント**（右打者なら右手） |
| **速度の方向** | **投手–捕手方向の1次元速度**（3D合成速度ではない） |
| **体幹運動の除去** | 手部速度から**骨盤セグメントの速度を減算**して体幹の並進成分を除去 |
| **閾値** | 各打者の**平均ピーク速度の10%**（平均ピーク速度：0.61 ± 0.09 m/s） |
| **サンプリング周波数** | 240 Hz |

論文原文（Data Analysis節）：
> "Hand velocity was defined as the velocity of the hand segment on the catcher's side (i.e., the right hand for a right-handed batter) relative to the velocity of the pelvis segment in the pitcher-catcher direction. This was done to remove the translation component of the trunk from the swing onset. Swing onset was defined as the moment at which the hand velocity exceeded a certain threshold, which was **10% of the mean peak velocity** for each batter (0.61 ± 0.09 m/s)."

### 本研究の現在の実装との比較

| 要素 | 現在の実装（暫定） | Nasu et al. (2020) |
|------|-------------------|---------------------|
| **使用マーカー** | `top`（バット先端） | 手部セグメント（グリップ側） |
| **速度の方向** | 3D合成速度 | 投手–捕手方向の1次元 |
| **体幹補正** | なし | 骨盤速度を減算 |
| **閾値の算出方法** | 試行内ピーク速度の5% | 打者ごとの平均ピーク速度の10% |

### 本研究への示唆

- グリップ側（`bottom` マーカー）を使うことが、スイング開始の検出として生理学的に妥当である可能性が高い（手部が最初に動き始めるため）。
- 閾値は **10%** が先行研究の根拠として使える。
- ただし本研究はモーションキャプチャ（反射マーカー）で計測しており、Nasu et al. の慣性センサーとは異なる。マーカー定義の対応関係（手部 ≒ `bottom` マーカー）を確認する必要がある。
- 骨盤セグメントの速度補正は、本研究でも適用できるか検討が必要（Qualisys で骨盤マーカーを計測しているか確認する）。

---

## 文献2：Punchihewa et al. (2020)【方針2の直接的な根拠】

- **著者・年**：Punchihewa, N. G., Miyazaki, S., Chosa, E., & Yamako, G. (2020)
- **タイトル**：Efficacy of Inertial Measurement Units in the Evaluation of Trunk and Hand Kinematics in Baseball Hitting
- **掲載誌**：Sensors, 20(24), 7331
- **DOI**：10.3390/s20247331

### 実験概要

- **被験者**：野球選手
- **計測機器**：IMU（サンプリング周波数 1000 Hz）
- **センサー取り付け位置**：胸骨、骨盤（左右後上腸骨棘の間）、**打者側の手の手袋の上（dorsal side of the leading hand over the batting glove）**
- **比較対象**：光学式モーションキャプチャ（OMCS）と比較して精度を検証

### スイング開始の定義

| 要素 | 定義の内容 |
|------|-----------|
| **使用センサー** | 打者側の手の手袋上のIMU（グリップノブ付近に相当） |
| **閾値** | **0.1 G**（重力加速度の0.1倍）の**絶対加速度閾値** |
| **定義文** | "A threshold value of 0.1 G was set to recognize initial hand movement during the forward swing phase." |

### 方針2との対応

- 手袋上のIMUは「グリップを握った手」の動きを捉えており、**方針2の「グリップ端付近の基準点の速度」と概念的に対応する**。
- ただし本研究（方針2）が採用する「ピーク速度の10%」という相対閾値とは異なり、Punchihewa (2020) は **絶対加速度閾値（0.1 G）** を使用している点に注意。
- 相対閾値（%）の根拠は引き続き Nasu et al. (2020) から引用する。

---

## 文献3：Cricket bat 加速度センサー研究【方針2の概念的な根拠】

- **著者・年**：Sarkar, P. K., James, D. A. 他（2011 年頃）
- **タイトル**：Triaxial Accelerometer Sensor Trials for Bat Swing Interpretation in Cricket
- **掲載誌**：Procedia Engineering（スポーツバイオメカニクス系学会誌）

### 実験概要

- **計測機器**：3軸加速度センサー（バット後面に直接取り付け）
- **剛体としての扱い**：バットとセンサーを剛体（rigid body）として扱い、剛体力学（rigid body dynamics）で運動を解析

### スイング開始の検出

- **「加速度データからドライブの開始と終了を直接かつ容易に特定できる（start and end of the drive can be readily determined from the accelerometer data）」** と記述されている。
- バット直付けセンサーの剛体的な運動から、スイング開始を特定することが技術的に成立することを示している。

### 方針2との対応

- **バット自体（剛体）にセンサーを取り付けてスイング開始を検出する**というアプローチを直接支持する。
- 計測機器の違い（加速度センサー vs. Qualisys 光学式剛体トラッキング）はあるが、「バット剛体の運動からスイング開始を定義できる」という原理は共通。

---

## まとめ：よく使われる定義のパターン

| パターン | 計測対象 | 速度の方向 | 閾値 | 出典 |
|----------|----------|-----------|------|------|
| A | 手部（グリップ側）センサー | 投手–捕手方向（1D） | 平均ピーク速度の10% | Nasu et al. (2020) |
| B | 打者側の手の手袋上のIMU | 3D合成（加速度） | 0.1 G（絶対加速度閾値） | Punchihewa et al. (2020) |
| C | バット直付けセンサー（剛体） | 剛体力学で算出 | 加速度データから直接特定 | Sarkar & James 他（2011） |
| D（現在の暫定実装） | バット先端（`top` マーカー） | 3D合成速度 | 試行内ピーク速度の5% | （先行研究の根拠なし） |

---

## 本研究における2つの方針の根拠まとめ

### 方針1（Nasu et al. 準拠・個別マーカー版）

| 要素 | 本研究の定義 | 根拠文献 |
|------|-------------|---------|
| 使用データ | `bottom` マーカー（グリップ端） | Nasu et al. (2020)：グリップ側手部を使用 |
| 速度方向 | 3D合成速度（体幹補正なし） | Nasu et al. からの変更（骨盤マーカーなし） |
| 閾値 | 平均ピーク速度の10% | Nasu et al. (2020) |

### 方針2（剛体トラッキング専用版）

| 要素 | 本研究の定義 | 根拠文献 |
|------|-------------|---------|
| 使用データ | バット剛体の原点（グリップ端付近に設定） | Punchihewa (2020)：手袋上センサー；Sarkar 他：バット直付けセンサー |
| 速度方向 | 3D合成速度 | — |
| 閾値 | 平均ピーク速度の10% | Nasu et al. (2020) から引用 |

> **閾値について**：Punchihewa (2020) は0.1 G の絶対加速度閾値を使用しているが、本研究では異なる計測系（光学式モーションキャプチャ）を使用するため、速度に基づく相対閾値（10%）を Nasu et al. から採用する。

---

*作成日：2026-06-08*
*更新日：2026-06-09（方針2の先行研究追記）*
*参照論文：Nasu et al. (2020); Punchihewa et al. (2020); Sarkar & James 他（2011）*
