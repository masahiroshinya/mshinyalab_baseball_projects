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

## まとめ：よく使われる定義のパターン

| パターン | マーカー | 速度の方向 | 閾値 | 出典 |
|----------|----------|-----------|------|------|
| A | 手部（グリップ側） | 投手–捕手方向（1D） | 平均ピーク速度の10% | Nasu et al. (2020) |
| B（現在の暫定実装） | バット先端（`top`） | 3D合成速度 | 試行内ピーク速度の5% | （先行研究の根拠なし） |

> **今後の方針**：Nasu et al. を参考に、`bottom` マーカー・10%閾値への変更を検討する。
> 骨盤補正・速度方向（1D vs 3D）についても実データで影響を比較するとよい。

---

*作成日：2026-06-08*
*参照論文：Nasu et al. (2020), Frontiers in Sports and Active Living*
