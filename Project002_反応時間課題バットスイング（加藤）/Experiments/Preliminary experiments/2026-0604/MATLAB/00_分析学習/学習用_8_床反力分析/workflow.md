# 学習ワークフロー：床反力（GRF）データを分析しよう

## このフォルダの目的

**床反力（Ground Reaction Force: GRF）** とは、バッターが地面を踏む力に対して地面から返ってくる力のことです。
このフォルダでは、床反力の基本概念を理解し、MATLABで床反力データを読み込み・可視化・分析するスキルを身につけることが目標です。

---

## 床反力とは何か（基礎知識）

### ニュートンの第3法則（作用・反作用の法則）

```
人が地面を踏む力 ← 作用 → 地面からの反力（= 床反力）
向き：逆    大きさ：同じ
```

バッターが地面を力強く踏み込む → 床が同じ大きさで逆向きの力を足に返す。
この「返ってきた力」が **床反力（Ground Reaction Force: GRF）** です。

### 床反力の3成分

床反力は3次元空間のベクトルなので、3つの方向に分解して考えます。

| 成分                       | 方向     | 野球打撃での意味                         |
| -------------------------- | -------- | ---------------------------------------- |
| **Fz（垂直分力）**   | 上下方向 | 体重を支える力。静止時は体重とほぼ等しい |
| **Fy（前後分力）**   | 前後方向 | 投手方向への踏み込み・蹴り出しの力       |
| **Fx（内外側分力）** | 左右方向 | 側方への重心移動に関わる力               |

> **注意**：座標系の方向（どの列がどの方向か）は実験室のセットアップによって異なります。
> 後のSTEPで実データを見ながら確認します。

### なぜ2枚のフォースプレートを使うのか？

バッティング動作では、**右足（軸足）と左足（踏み込み足）に別々の力がかかります**。
2枚のフォースプレートを使うことで、両足それぞれの力を独立に計測できます。

```
スイング動作中の垂直分力の変化（イメージ）

Fz（垂直分力）

  体重比
  1.0│ ██████                      ████████
     │ ██████                ██████
     │ ██                ████
  0.0│─────────────────────────────────── 時間
        ← 軸足（後ろ足） →

  1.0│              ██████████████████████
     │       ███████
     │ ██████
  0.0│─────────────────────────────────── 時間
        ← 踏み込み足（前の足） →
              ↑LED点灯
```

スイングの開始とともに、**軸足の力が減り、踏み込み足の力が増える** — これを **体重移動（重心移動）** と呼びます。

---

## データ構造の確認

### load_qualisys_mat が返すフォースプレートデータ

`load_qualisys_mat` を実行すると、`Data` 構造体に以下のフィールドが含まれます。

| フィールド名              | サイズ              | 内容                                     |
| ------------------------- | ------------------- | ---------------------------------------- |
| `Data.Force1`           | nAnalogSamples × 3 | プレート1の力\[N\]（列：Fx, Fy, Fz）     |
| `Data.Force2`           | nAnalogSamples × 3 | プレート2の力\[N\]（列：Fx, Fy, Fz）     |
| `Data.Moment1`          | nAnalogSamples × 3 | プレート1のモーメント\[N·m\]            |
| `Data.Moment2`          | nAnalogSamples × 3 | プレート2のモーメント\[N·m\]            |
| `Data.Analog.Frequency` | スカラー            | アナログデータのサンプリング周波数\[Hz\] |

> **サンプリング周波数の違い**：
>
> - マーカーデータ：`Data.FrameRate`（例：200 Hz）
> - 床反力データ：`Data.Analog.Frequency`（例：1000 Hz）
>
> 床反力は素早い力の変化を捉えるために、マーカーより高いサンプリング周波数で計測されます。

### 符号の意味

`load_qualisys_mat.m` の中で符号を反転してあります（`force1 = -Data.Force(1).Force'`）。
その結果、**正の Fz は「床が人を押し上げる力（上向き）」** を意味します。

```
Fz > 0 → その足が床を踏んでいる（体重がかかっている）
Fz = 0 → その足が床から離れている、または力がかかっていない
```

---

## ファイル構成

| ファイル名                      | 種類         | 役割                                     |
| ------------------------------- | ------------ | ---------------------------------------- |
| `workflow.md`（このファイル） | ドキュメント | 学習手順の説明                           |
| `s8_forstudy_scratch8.m`      | スクリプト   | 床反力データを手を動かして確かめる練習帳 |
| `技術説明.md`                 | ドキュメント | 床反力分析の技術的な詳細説明             |

---

## 全体の流れ

```
[1] データ読み込み          → load_qualisys_mat で1試行を読み込む
[2] データ構造の確認        → Force1・Force2 のサイズとサンプリング周波数を確認する
[3] 生波形の可視化          → 試行全体の Fz（垂直分力）をプロットする
[4] LED基準の時間軸         → LEDタイミングに合わせた時間軸でプロットする
[5] 体重推定と正規化        → 静止期の Fz から体重を推定し、BW単位に変換する
[6] 重心移動の観察          → 正規化済み Fz を重ねてプロットし、体重移動を観察する
[7] 前後分力の確認          → Fy（前後方向分力）も可視化する
[8] 条件別平均の可視化      → 正規化前（N）と正規化後（BW）の条件別平均を比較する
[9] 個別試行と平均の重ね描き → 各試行を薄く、平均を濃く重ねて描画し、ばらつきを観察する
[10] 考察                  → バットスイングと床反力の関係を考える
```

---

## STEP 1：フォルダの設定とファイルの準備

### MATLABのカレントフォルダを設定する

MATLABのカレントフォルダを以下に設定してください：

```
Preliminary experiments/2026-0604/MATLAB/
```

`x1_RawData/`、`x2_Data/` などのデータフォルダはこの直下にあるため、
カレントフォルダを `MATLAB/` にすると相対パスで簡単にアクセスできます。

### 補助関数について

`load_qualisys_mat.m` や `lineplot.m` などの補助関数は `2026-0604/MATLAB/` に直接置かれています。
カレントフォルダを `MATLAB/` に設定すれば、`addpath` は不要です。

### スクリプトファイルを確認する

`2026-0604/MATLAB/学習用_8_床反力分析/` フォルダに `s8_forstudy_scratch8.m` が作成済みです。
エディターで開いてください。

### 確認ポイント

- [X] MATLABのカレントフォルダが `2026-0604/MATLAB/` になっている
- [X] `s8_forstudy_scratch8.m` をエディターで開いた

---

## STEP 2：データを読み込んでデータ構造を確認する

### やること

`2026-0604` の生データから1ファイルを読み込んで、フォースプレートデータの構造を確認します。

### コードを書こう

```matlab
clear
close all
clc

% ---- データの読み込み ----
folderName = 'x1_RawData/2026-0604_予備実験' ;
fileName   = 'S01_free0001' ;

Data = load_qualisys_mat(folderName, fileName) ;

% ---- サンプリング周波数の確認 ----
fprintf('=== サンプリング周波数 ===\n') ;
fprintf('マーカー      : %d Hz\n', Data.FrameRate) ;
fprintf('アナログ（GRF）: %d Hz\n', Data.Analog.Frequency) ;
fprintf('\n') ;

% ---- Force1・Force2 のサイズ確認 ----
fprintf('=== データサイズの確認 ===\n') ;
fprintf('Force1 のサイズ : %d 行 × %d 列\n', size(Data.Force1, 1), size(Data.Force1, 2)) ;
fprintf('Force2 のサイズ : %d 行 × %d 列\n', size(Data.Force2, 1), size(Data.Force2, 2)) ;
fprintf('\n') ;

% ---- 垂直分力（Fz）を取り出す ----
% Force1(:, 3) → Fz（3列目 = 垂直方向）
Fz1 = Data.Force1(:, 3) ;
Fz2 = Data.Force2(:, 3) ;

fprintf('=== 垂直分力（Fz）の確認 ===\n') ;
fprintf('Fz1 の最大値 : %6.1f N\n', max(Fz1)) ;
fprintf('Fz1 の最小値 : %6.1f N\n', min(Fz1)) ;
fprintf('Fz2 の最大値 : %6.1f N\n', max(Fz2)) ;
fprintf('Fz2 の最小値 : %6.1f N\n', min(Fz2)) ;
```

> **列番号と力の方向の対応：**
>
> | 列番号 | 取り出し方            | 方向               |
> | ------ | --------------------- | ------------------ |
> | 1列目  | `Data.Force1(:, 1)` | Fx（x方向）        |
> | 2列目  | `Data.Force1(:, 2)` | Fy（y方向）        |
> | 3列目  | `Data.Force1(:, 3)` | Fz（z方向 = 垂直） |

### `fprintf` の書式指定（`%6.1f` の読み方）

`fprintf` の第1引数（文字列）の中に `%...f` という記号を書くと、数値を好きな形式で表示できます。

```
fprintf('Fz1 の最大値：%6.1f N\n', max(Fz1))
                       ↑ここが書式指定
```

| 記号   | 意味                                | 例：`589.2` の場合 |
| ------ | ----------------------------------- | -------------------- |
| `%`  | 書式指定の開始                      | —                   |
| `6`  | 表示幅（全体で6文字分確保・右詰め） | `" 589.2"`         |
| `.1` | 小数点以下の桁数（1桁）             | `"589.2"`          |
| `f`  | 小数（float）として表示             | —                   |
| `\n` | 改行（次の行に移る）                | —                   |

**幅指定の効果（複数行を並べた例）：**

```
Fz1 の最大値：1021.5 N   ← 幅6で右詰めになっているので
Fz1 の最小値：   0.0 N   ← 小数点の位置が縦に揃う
Fz2 の最大値： 912.3 N
Fz2 の最小値：   0.0 N
```

幅を揃えることで、出力が読みやすくなります。

---

### 確認ポイント

- [X] コードを実行してエラーが出ないことを確認する
- [X] `Data.Analog.Frequency` の値を確認する（何 Hz か？）
- [X] `Force1` の行数が「試行時間 [s] × fsAnalog [Hz]」と一致することを確認する
  - 例：試行が5秒で 1000 Hz なら → 5000 行のはず
- [X] `Fz1` と `Fz2` の最大値を確認する
  - 体重60 kg なら 60 × 9.81 ≈ **589 N** 程度が上限の目安

---

## STEP 3：Fz（垂直分力）の生波形をプロットする

### やること

試行全体にわたる垂直分力の波形を確認します。まず「試行開始からの時間」を横軸にして、
データがどんな形をしているか直感的に理解しましょう。

### コードを書こう（STEP 2 の続きに追加）

```matlab
% ---- 時間軸を作成する（試行開始を t=0 とする） ----
nAnalog  = length(Fz1) ;
fsAnalog = Data.Analog.Frequency ;
tAnalog  = [1:nAnalog] / fsAnalog ;   % 単位：秒 [s]

% ---- Fz をプロットする ----
figure(1)

subplot(2, 1, 1)
plot(tAnalog, Fz1)
xlabel('Time [s]（試行開始からの経過時間）')
ylabel('Fz1 [N]')
title('垂直分力 — プレート1')
grid on

subplot(2, 1, 2)
plot(tAnalog, Fz2)
xlabel('Time [s]（試行開始からの経過時間）')
ylabel('Fz2 [N]')
title('垂直分力 — プレート2')
grid on
```

### `tAnalog = [1:nAnalog] / fsAnalog` の意味

この1行は「**サンプル番号の配列を、秒単位の時間軸に変換する**」処理です。

**ステップ① `[1:nAnalog]` — 整数の連番を作る**

`nAnalog` が 5000 なら `[1, 2, 3, ..., 5000]` という配列になります。
これは「何番目のサンプルか」というサンプル番号であり、単位はまだ「番号」です。

**ステップ② `/ fsAnalog` — 秒に変換する**

`fsAnalog = 1000` Hz の場合、配列全体を 1000 で割ります：

| サンプル番号 | ÷ fsAnalog |   時刻   |
| :----------: | :---------: | :------: |
|      1      |   ÷ 1000   | 0.001 秒 |
|     500     |   ÷ 1000   | 0.500 秒 |
|     1000     |   ÷ 1000   | 1.000 秒 |
|     5000     |   ÷ 1000   | 5.000 秒 |

**なぜ変換が必要か**

```
変換前（サンプル番号のまま）    変換後（秒単位）
plot(Fz1)                      plot(tAnalog, Fz1)

x軸: 0, 1000, 2000, 5000       x軸: 0, 1.0, 2.0, 5.0 [s]
     （意味がわかりにくい）           （直感的にわかる）
```

`/ fsAnalog` で割ることで「試行開始から何秒後か」という直感的な単位になり、グラフが読みやすくなります。

---

### Fz（垂直分力）の典型的な波形

```
Fz のイメージ

  N
600│ ████████████                    █████████████
   │ █████████████               █████████████████
   │ ██████████████           ██████████████████████
 0 │──────────────────────────────────────────── 時間 [s]

      ↑準備（静止期）       ↑スイング（力が大きく変化）
```

### 確認ポイント

- [X] Figure 1 にグラフが表示されることを確認する
- [X] 試行の前後に「ほぼ一定の値が続く区間（静止期）」があることを確認する
- [X] スイング中に値が大きく変化することを確認する
- [X] プレート1とプレート2で、波形の形が異なることを確認する（片方が増えると、もう片方は減る？）

---

## STEP 4：LED タイミングを基準に時間軸を設定する

### やること

前の学習（s5）で習ったLEDタイミング検出を、床反力データに適用します。
LED点灯を t = 0 とした時間軸で、力の変化を観察します。

> **重要**：床反力データと LED データは同じ `Data.Analog.Frequency`（アナログサンプリングレート）で記録されています。
> マーカーデータとは異なるため、`tCueAnalog` をそのまま時間軸の基準として使えます。

### コードを書こう（STEP 3 の続きに追加）

```matlab
% ---- LED タイミングを取得する ----
led = Data.LEDData(:, 2) ;   % LED 信号チャンネル

tCueAnalog = find(abs(led) > 2, 1, 'first') ;

if isempty(tCueAnalog)
    fprintf('LED タイミングが検出されませんでした\n') ;
else
    fprintf('=== LED タイミング ===\n') ;
    fprintf('LED 点灯サンプル番号 : %d\n', tCueAnalog) ;
    fprintf('LED 点灯時刻（試行開始から）: %.3f s\n', tCueAnalog / fsAnalog) ;
end

% ---- LED 基準の時間軸を作成する ----
% t = 0 がLED点灯、t < 0 がLED点灯前、t > 0 がLED点灯後
tFromLED = ([1:nAnalog] - tCueAnalog) / fsAnalog ;

% ---- LED 基準の Fz をプロットする ----
figure(2)
plotTimeRange = [-1, 3] ;   % LED点灯の1秒前から3秒後まで表示する

subplot(2, 1, 1)
plot(tFromLED, Fz1)
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Fz1 [N]')
title('垂直分力 プレート1（LED点灯を t=0 として表示）')
lineplot(0, 'v', 'r--')       % LED点灯の位置を赤い破線で示す
grid on

subplot(2, 1, 2)
plot(tFromLED, Fz2)
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Fz2 [N]')
title('垂直分力 プレート2（LED点灯を t=0 として表示）')
lineplot(0, 'v', 'r--')
grid on
```

> **`lineplot` とは？**：このプロジェクトの補助関数で、現在の axes に垂直・水平な補助線を描きます。
> `lineplot(0, 'v', 'r--')` で x=0（LED点灯時刻）に赤い破線を引きます（`'v'` = vertical）。

> **`tFromLED` の作り方（詳しく）：**
>
> ```
> ([1:nAnalog] - tCueAnalog) / fsAnalog
>
> サンプル番号 1, 2, 3, ..., tCueAnalog, ..., nAnalog
>   ↓（tCueAnalogを引く）
>     負の値,  ...,      0,         ..., 正の値
>   ↓（fsAnalogで割る）
>   秒単位の時間（LED点灯を0秒とした時間軸）
> ```

### 確認ポイント

- [ ] `tCueAnalog` の値がコマンドウィンドウに表示されることを確認する
- [ ] Figure 2 で t = 0 に赤い破線が表示されることを確認する
- [ ] LED点灯後（t > 0）に力の変化が起きることを目で確認する

---

## STEP 5：体重を推定して正規化する

### なぜ正規化が必要か？

被験者ごとに体重が異なるため、力の生の値（N 単位）で比較すると、
体重の重い人のほうが自然と大きな値になります。
**体重で割る（正規化する）** ことで、体重に依存しない比較ができます。

$$
F_{\text{BW}} = \frac{F_{\text{raw}} \text{[N]}}{\text{体重 [N]}}
$$

単位は **BW（Body Weight; 体重比）** と表記します。静止時は Fz1 + Fz2 ≈ 1.0 BW になります。

### 体重の推定方法

**静止期（バッターが動かずに立っている区間）** では：

```
Fz1（静止期の平均）+ Fz2（静止期の平均）= 体重 [N]
```

静止期として「試行開始直後の0.5秒間」を使うと比較的安定して推定できます。

### コードを書こう（STEP 4 の続きに追加）

```matlab
% ---- 静止期のサンプル範囲を決める ----
% 録画開始からLED点灯直前までを静止期とする（プロトコールの定義：LED点灯まで静止）
staticStart = 1 ;
staticEnd   = tCueAnalog - 1 ;

% ---- 静止期の平均 Fz から体重を推定する ----
meanFz1_static = mean(Fz1(staticStart:staticEnd)) ;
meanFz2_static = mean(Fz2(staticStart:staticEnd)) ;
bodyWeight_N   = meanFz1_static + meanFz2_static ;

fprintf('=== 体重の推定 ===\n') ;
fprintf('プレート1 Fz（静止期平均）: %.1f N\n', meanFz1_static) ;
fprintf('プレート2 Fz（静止期平均）: %.1f N\n', meanFz2_static) ;
fprintf('推定体重 : %.1f N（約 %.1f kg）\n', bodyWeight_N, bodyWeight_N / 9.81) ;

% ---- 垂直分力を体重で正規化する ----
Fz1_BW = Fz1 / bodyWeight_N ;   % 単位：BW（体重比）
Fz2_BW = Fz2 / bodyWeight_N ;
```

### `mean(Fz1(staticStart:staticEnd))` の読み方

この1行は「内側から外側へ」順番に読むと理解しやすいです。

| 順番 | 部分                           | 意味                                       | 例（tCueAnalog = 1000 の場合）          |
| :--: | ------------------------------ | ------------------------------------------ | --------------------------------------- |
|  ①  | `staticStart:staticEnd`      | 静止期のインデックス範囲（連番）を作る     | `[1, 2, 3, ..., 999]`                 |
|  ②  | `Fz1(staticStart:staticEnd)` | `Fz1` から静止期のサンプルだけを取り出す | `[580.1, 582.3, 579.8, ...]`（999個） |
|  ③  | `mean(...)`                  | 取り出したサンプルの平均値を計算する       | `→ 580.5 N`                          |
|  ④  | `meanFz1_static = ...`       | 計算結果を変数に保存する                   | `meanFz1_static = 580.5`              |

```
Fz1 = [580, 582, 579, ..., (静止期 999サンプル), ..., 200, 150, ...]
       ←── Fz1(staticStart:staticEnd) で切り出す ──→  ← スイング中 →

mean([580, 582, 579, ...]) → 580.5 N  ← これが静止期の平均値
```

> **注意**：`tCueAnalog` の検出に失敗している場合（LEDが検出されなかった場合）、
> `staticEnd` が正しく設定されません。STEP 4 で LED タイミングが正常に検出されていることを先に確認してください。

### 確認ポイント

- [ ] `bodyWeight_N` の推定値を確認する
  - 体重60 kg なら 60 × 9.81 ≈ **589 N**、体重70 kg なら ≈ **687 N** 程度
- [ ] Figure 1 の静止期（0〜0.5 s 付近）で Fz1 と Fz2 の合計がほぼ一定であることを目で確認する

---

## STEP 6：正規化済み Fz を重ねて体重移動を観察する

### やること

正規化した垂直分力をプレート1とプレート2で同じグラフに重ねてプロットし、
**体重移動（重心移動）** のパターンを観察します。

### コードを書こう（STEP 5 の続きに追加）

```matlab
% ---- 正規化済み Fz を重ねてプロット ----
figure(3)
plotTimeRange = [-1, 3] ;

plot(tFromLED, Fz1_BW, 'b-', 'LineWidth', 1.2) ;
hold on
plot(tFromLED, Fz2_BW, 'r-', 'LineWidth', 1.2) ;
set(gca, 'xlim', plotTimeRange) ;
set(gca, 'ylim', [-0.1, 1.4]) ;
xlabel('Time from LED [s]')
ylabel('Vertical Force [BW]')
title('垂直分力の体重移動パターン（正規化済み）')
legend('プレート1（青）', 'プレート2（赤）', 'Location', 'northwest')
lineplot(0, 'v', 'k--')
grid on
```

### 観察すべきこと

グラフを見て、以下の問いを考えてください：

1. **静止期（t < 0）**：プレート1とプレート2で、どちらに多く体重がかかっているか？
2. **LED点灯後（t > 0）**：どちらのプレートの力が最初に変化し始めるか？
3. **体重はどちらからどちらへ移動するか？**（「軸足」→「踏み込み足」の方向）
4. **2枚のプレートの合計値（Fz1_BW + Fz2_BW）はほぼ一定か？**
   - 一定であれば、被験者の重心は上下に動いていない（静止に近い）
   - 大きく変動するなら、跳び上がったり膝を曲げたりして重心が上下している

```
典型的な体重移動パターン（右打者のイメージ）

BW
1.0│ ─────────────────────────────────────────── 1.0 BW（体重）
   │
   │  プレート1（青）                    ●●●●●●●
   │ ●●●●●●●●●●●●●●      ●●●●●
   │                   ●●●●●●
   │
   │                                  ●●●●●●●●●
   │             ●●●●●●●●●
   │ ●●●●●●●                         プレート2（赤）
   │──────────────────────────────────────── 時間
           ↑LED点灯
```

### 確認ポイント

- [ ] Figure 3 にグラフが表示されることを確認する
- [ ] 2本の曲線が逆の動きをすること（一方が増えると他方が減る）を確認する
- [ ] どちらがプレート1（軸足）で、どちらがプレート2（踏み込み足）かを考える
- [ ] 次のコードを実行して、合計値も確認する

```matlab
% 合計値（Fz1 + Fz2）を確認する
FzTotal_BW = Fz1_BW + Fz2_BW ;
figure(4)
plot(tFromLED, FzTotal_BW, 'k-')
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Total Fz [BW]')
title('垂直分力の合計（プレート1 + プレート2）')
lineplot(0, 'v', 'r--')
grid on
```

> 合計値が静止期の約 **1.0 BW** 付近で安定していれば、正規化がうまくいっています。

---

## STEP 7：前後方向分力（Fy）も確認する

### やること

垂直分力（Fz）に加えて、前後方向分力（Fy）も可視化します。
Fy はバッターが「前に踏み出す力」や「投手側に蹴り出す力」を反映しています。

### コードを書こう（STEP 6 の続きに追加）

```matlab
% ---- 前後方向分力（Fy）を取り出して正規化する ----
Fy1 = Data.Force1(:, 2) ;
Fy2 = Data.Force2(:, 2) ;

Fy1_BW = Fy1 / bodyWeight_N ;
Fy2_BW = Fy2 / bodyWeight_N ;

% ---- Fz と Fy を上下に並べてプロットする ----
figure(5)
plotTimeRange = [-1, 3] ;

subplot(2, 1, 1)
plot(tFromLED, Fz1_BW, 'b-') ; hold on
plot(tFromLED, Fz2_BW, 'r-') ;
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Fz [BW]')
title('垂直分力（Fz）')
legend('プレート1', 'プレート2', 'Location', 'northwest')
lineplot(0, 'v', 'k--') ; grid on

subplot(2, 1, 2)
plot(tFromLED, Fy1_BW, 'b-') ; hold on
plot(tFromLED, Fy2_BW, 'r-') ;
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Fy [BW]')
title('前後方向分力（Fy）')
legend('プレート1', 'プレート2', 'Location', 'northwest')
lineplot(0, 'v', 'k--') ; grid on
```

### 確認ポイント

- [ ] Figure 5 が表示されることを確認する
- [ ] Fz（垂直）と Fy（前後）で、波形の形や大きさが異なることを確認する
  - 一般に、バッティングでは **Fz が最も大きく** 変化する
  - Fy は比較的小さいが、「前への踏み込み」と「蹴り返し」のパターンを示す
- [ ] Fy の正/負がどちらの方向（前か後か）を意味するか、波形から考える

---

## STEP 8：条件別 GRF 時系列の平均と比較（正規化前・正規化後）

### やること

これまでは1試行のデータを可視化してきました。
このステップでは **すべての試行の平均** をとり、**3つの条件（free / simple / gonogo）を重ねて比較**します。
さらに **正規化前（N）と正規化後（BW）の両方**を出力して、正規化の効果も合わせて確認します。

> **なぜ平均をとるのか？**
> 1試行だけでは、その試行固有のばらつき（準備タイミングのずれ・疲労など）が含まれます。
> 複数試行の平均をとることで、条件に特有の安定したパターンが浮かび上がります。

> **なぜ gonogo 条件の NoGo 試行を除くのか？**
> NoGo 試行では被験者はスイングしません。スイングがないと体重移動も起きないため、
> Go 試行と混ぜて平均すると波形が打ち消し合ってしまいます。

> **なぜ正規化前・後の両方を出すのか？**
> - **正規化前（N）**：絶対値での比較。条件間で力の大きさそのものに違いがあるか確認できます。
> - **正規化後（BW）**：体重比での比較。被験者間の体重差を除去した形で条件間を比較できます。
> 両方を並べることで「条件間の差は体重のせいか、それとも本当の力の違いか」を判断する材料になります。

### このステップで使うデータ

| 変数名                     | 読み込み元                                   | 内容                                             |
| -------------------------- | -------------------------------------------- | ------------------------------------------------ |
| `DataArray`              | `x2_Data/Data%02d.mat`                     | 試行×条件の構造体配列                           |
| `SingleTrialResultArray` | `x5_SingleTrialAnalysisResultsChecked/...` | 各試行の分析結果（LED タイミング・CueText など） |

### コードを書こう

```matlab
% ---- データの読み込み ----
iSubject = 1 ;   % 被験者番号
load(sprintf('x2_Data/Data%02d', iSubject))
load(sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;
nTrial     = size(DataArray, 1) ;

% ---- 固定時間軸の設定（全試行を LED 基準で揃えるための共通軸）----
plotRange = [-1, 3] ;
fsAnalog  = DataArray(1, 1).AnalogFs ;
nPlot     = round((plotRange(2) - plotRange(1)) * fsAnalog) ;
tPlot     = plotRange(1) + [0:nPlot-1] / fsAnalog ;

condColors = {'g', 'b', 'r'} ;   % free=緑, simple=青, gonogo=赤

figure(6) ; clf   % 正規化前（N）
figure(7) ; clf   % 正規化後（BW）

for iCondition = 1:nCondition

    condName = ConditionNameArray{iCondition} ;

    Fz1_raw_cell  = {} ;   % 正規化前の波形を溜めるセル配列
    Fz2_raw_cell  = {} ;
    Fz1_norm_cell = {} ;   % 正規化後の波形を溜めるセル配列
    Fz2_norm_cell = {} ;

    for iTrial = 1:nTrial

        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;

        % NoGo 試行・エラー試行・データなし試行をスキップ
        if ~strcmp(Result.CueText, 'Go')
            continue
        end
        if isnan(Result.TCueMarker) || ~isfield(Data, 'Force1') || isempty(Data.Force1)
            continue
        end

        Fz1        = Data.Force1(:, 3) ;
        Fz2        = Data.Force2(:, 3) ;
        nAnalog    = length(Fz1) ;
        tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs) ;

        if tCueAnalog < 2
            continue
        end

        % 体重推定（LED 点灯前の静止期）
        bw = mean(Fz1(1:tCueAnalog-1)) + mean(Fz2(1:tCueAnalog-1)) ;
        if bw <= 0
            continue
        end

        % 固定時間窓を切り出す（LED 基準 -1 〜 +3 秒）
        iStart = tCueAnalog + round(plotRange(1) * fsAnalog) ;
        iEnd   = iStart + nPlot - 1 ;

        if iStart < 1 || iEnd > nAnalog
            continue
        end

        % 正規化前（N）と正規化後（BW）を同時に蓄積する
        Fz1_raw_cell{end+1}  = Data.Force1(iStart:iEnd, 3) ;
        Fz2_raw_cell{end+1}  = Data.Force2(iStart:iEnd, 3) ;
        Fz1_norm_cell{end+1} = Data.Force1(iStart:iEnd, 3) / bw ;
        Fz2_norm_cell{end+1} = Data.Force2(iStart:iEnd, 3) / bw ;

    end  % iTrial

    if isempty(Fz1_raw_cell)
        continue
    end

    nValid        = length(Fz1_raw_cell) ;
    Fz1_raw_mean  = mean(cell2mat(Fz1_raw_cell),  2)' ;
    Fz2_raw_mean  = mean(cell2mat(Fz2_raw_cell),  2)' ;
    Fz1_norm_mean = mean(cell2mat(Fz1_norm_cell), 2)' ;
    Fz2_norm_mean = mean(cell2mat(Fz2_norm_cell), 2)' ;

    % Figure 6：正規化前（N）
    figure(6)
    subplot(2, 1, 1) ; hold on
    plot(tPlot, Fz1_raw_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid)) ;
    subplot(2, 1, 2) ; hold on
    plot(tPlot, Fz2_raw_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid)) ;

    % Figure 7：正規化後（BW）
    figure(7)
    subplot(2, 1, 1) ; hold on
    plot(tPlot, Fz1_norm_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid)) ;
    subplot(2, 1, 2) ; hold on
    plot(tPlot, Fz2_norm_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid)) ;

end  % iCondition

% Figure 6 の装飾（正規化前・YLim は自動）
figure(6)
subplot(2, 1, 1)
lineplot(0, 'v', 'k--') ;
set(gca, 'XLim', plotRange) ;
xlabel('LEDからの時間 [s]') ; ylabel('Fz [N]') ;
title(sprintf('Subject %02d  プレート１（後ろ足）— 条件別平均（正規化前）', iSubject)) ;
legend('Location', 'northwest') ; grid on

subplot(2, 1, 2)
lineplot(0, 'v', 'k--') ;
set(gca, 'XLim', plotRange) ;
xlabel('LEDからの時間 [s]') ; ylabel('Fz [N]') ;
title(sprintf('Subject %02d  プレート２（前の足）— 条件別平均（正規化前）', iSubject)) ;
legend('Location', 'northwest') ; grid on

% Figure 7 の装飾（正規化後・YLim 固定）
figure(7)
subplot(2, 1, 1)
lineplot(0, 'v', 'k--') ;
set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]) ;
xlabel('LEDからの時間 [s]') ; ylabel('Fz [BW]') ;
title(sprintf('Subject %02d  プレート１（後ろ足）— 条件別平均（正規化後）', iSubject)) ;
legend('Location', 'northwest') ; grid on

subplot(2, 1, 2)
lineplot(0, 'v', 'k--') ;
set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]) ;
xlabel('LEDからの時間 [s]') ; ylabel('Fz [BW]') ;
title(sprintf('Subject %02d  プレート２（前の足）— 条件別平均（正規化後）', iSubject)) ;
legend('Location', 'northwest') ; grid on
```

### コードの重要ポイント

**① NoGo 試行の除外**

```matlab
if ~strcmp(Result.CueText, 'Go')
    continue
end
```

`Result.CueText` には `'Go'` または `'NoGo'` が入っています。
`strcmp` は文字列を比較する関数で、`~strcmp(...)` は「Go でないとき」という意味です。
`continue` はループの残りの処理をスキップして次の試行へ進みます。

**② 固定時間窓の切り出し**

```matlab
iStart = tCueAnalog + round(plotRange(1) * fsAnalog) ;
iEnd   = iStart + nPlot - 1 ;
```

全試行を「LED点灯の1秒前から3秒後」という同じ長さの窓で切り出します。
これにより、すべての試行が同じ時間軸に揃い、平均が計算できます。

**③ 正規化前・後を同時に蓄積する**

```matlab
Fz1_raw_cell{end+1}  = Data.Force1(iStart:iEnd, 3) ;        % 正規化なし（N）
Fz1_norm_cell{end+1} = Data.Force1(iStart:iEnd, 3) / bw ;   % 正規化あり（BW）
```

同じ切り出し窓のデータを2つのセル配列に同時に保存します。`/ bw` の有無が唯一の違いです。

**④ `cell2mat` と `mean` の組み合わせ**

```
Fz1_raw_cell = { [col1], [col2], ..., [colN] }   % 1 × N のセル配列
                  ↓（各要素は nPlot × 1 の列ベクトル）

cell2mat(Fz1_raw_cell) → nPlot × N の行列

mean(..., 2)           → 各行の平均（列方向 = 試行方向）→ nPlot × 1 の列ベクトル
                         ↑ 第2引数 '2' は「2次元目（列方向）に平均をとる」という意味

' （転置）             → 1 × nPlot の行ベクトル（plot に渡す形）
```

### 確認ポイント

- [ ] Figure 6（正規化前・N）に 3 条件の波形が色分けして表示されることを確認する
- [ ] Figure 7（正規化後・BW）に 3 条件の波形が色分けして表示されることを確認する
- [ ] Figure 6 と Figure 7 でグラフの形は同じで、Y 軸の単位（N と BW）だけが異なることを確認する
- [ ] 凡例の `(n=xx)` で各条件の有効試行数（Go 試行数）を確認する
- [ ] 3 条件の GRF パターンに違いがあるか観察する
  - **free 条件**（緑）：自由スイング → 体重移動のタイミングや大きさはどうか？
  - **simple 条件**（青）：Go 刺激でスイング → free との違いはあるか？
  - **gonogo 条件**（赤）：Go 試行のみ → 見極めが必要な分、動き出しが遅くなるか？

---

## STEP 9：各試行を薄く、平均を濃く重ねて描画する（条件ごとに図を分ける）

### やること

STEP 8 では条件ごとの **平均波形だけ** をプロットしました。
このステップでは、平均を計算する前の **各試行の生波形** も同じグラフに **薄く** 重ね描きし、
その上から平均波形を **濃く（太く）** 重ねます。

> **なぜ個別試行も表示するのか？**
> 平均だけを見ていると、「試行間のばらつきがどれくらい大きいか」「外れ値（極端に大きい/小さい試行）があるか」が分かりません。
> 個別波形を薄く表示することで、平均線がその条件を代表する波形として妥当かどうかを目で判断できるようになります。

> **なぜ透明度（alpha）ではなく「薄い色」を使うのか？**
> MATLAB の `plot` で描く線に透明度をつける公式な方法は用意されていません（`h.Color(4) = alpha` という非公式の裏技はありますが、バージョンによって挙動が変わることがあります）。
> 代わりに、条件色（緑・青・赤）を **白に近づけた薄い色** を新しく用意し、それを個別試行用の色として使います。公式にサポートされた方法なので、バージョンに依存せず確実に動作します。

> **なぜ3条件を1枚のグラフに重ねないのか？**
> 最初は STEP 8 と同じように、1枚のグラフに free / simple / gonogo をすべて重ねて描画してみました。
> しかし各条件で何十本もの個別試行の線が重なると、色が入り混じって非常に見づらくなります。
> そこで、**条件ごとに別々の figure** に分けることにしました。1つの図には1条件分の「個別試行（薄）＋平均（濃）」だけが描かれるため、ばらつきの大きさが直感的に読み取れます。

### このステップで使うデータ

条件ごとに figure 番号を分けます。プレート1・2は STEP 8 と同じく `subplot(2,1,...)` で1つの figure の中に上下に並べます。

| 条件     | 正規化前（N）の figure 番号 | 正規化後（BW）の figure 番号 |
| -------- | ---------------------------- | ------------------------------ |
| free     | 6                             | 9                               |
| simple   | 7                             | 10                              |
| gonogo   | 8                             | 11                              |

### コードを書こう（STEP 8 のコードを次のように拡張する）

STEP 8 の `condColors` の定義の下に、個別試行用の薄い色と、条件ごとの figure 番号の対応表を追加します。

```matlab
condColors      = {'g', 'b', 'r'} ;                          % 平均線用（濃い色）
condColorsLight = {[0.7 1 0.7], [0.7 0.7 1], [1 0.7 0.7]} ;  % 個別試行用（薄い色）

figRawByCondition  = [6, 7, 8] ;    % 正規化前（N）：free, simple, gonogo
figNormByCondition = [9, 10, 11] ;  % 正規化後（BW）：free, simple, gonogo

for iFig = [figRawByCondition, figNormByCondition]
    figure(iFig) ; clf
end
```

そして、STEP 8 の `for iCondition = 1:nCondition` ループの中の、平均を計算・描画している部分（`nValid = length(Fz1_raw_cell) ;` 以降）を、次のように「①条件専用の figure を選ぶ → ②個別試行を薄く描画 → ③平均を濃く描画」の順番に書き換えます。

```matlab
    nValid  = length(Fz1_raw_cell) ;
    figRaw  = figRawByCondition(iCondition) ;   % ① この条件専用の figure 番号
    figNorm = figNormByCondition(iCondition) ;

    % ② 各試行のFzを薄く描画する（先に描いて背面に回す）
    figure(figRaw)
    subplot(2, 1, 1) ; hold on
    for iTrial = 1:nValid
        plot(tPlot, Fz1_raw_cell{iTrial}, 'Color', condColorsLight{iCondition}, ...
            'LineWidth', 0.5, 'HandleVisibility', 'off') ;
    end
    subplot(2, 1, 2) ; hold on
    for iTrial = 1:nValid
        plot(tPlot, Fz2_raw_cell{iTrial}, 'Color', condColorsLight{iCondition}, ...
            'LineWidth', 0.5, 'HandleVisibility', 'off') ;
    end

    figure(figNorm)
    subplot(2, 1, 1) ; hold on
    for iTrial = 1:nValid
        plot(tPlot, Fz1_norm_cell{iTrial}, 'Color', condColorsLight{iCondition}, ...
            'LineWidth', 0.5, 'HandleVisibility', 'off') ;
    end
    subplot(2, 1, 2) ; hold on
    for iTrial = 1:nValid
        plot(tPlot, Fz2_norm_cell{iTrial}, 'Color', condColorsLight{iCondition}, ...
            'LineWidth', 0.5, 'HandleVisibility', 'off') ;
    end

    % ③ 全試行の平均Fzを濃く描画する（後に描いて前面に出す）
    Fz1_raw_mean  = mean(cell2mat(Fz1_raw_cell),  2)' ;
    Fz2_raw_mean  = mean(cell2mat(Fz2_raw_cell),  2)' ;
    Fz1_norm_mean = mean(cell2mat(Fz1_norm_cell), 2)' ;
    Fz2_norm_mean = mean(cell2mat(Fz2_norm_cell), 2)' ;

    figure(figRaw)
    subplot(2, 1, 1) ; hold on
    plot(tPlot, Fz1_raw_mean, condColors{iCondition}, 'LineWidth', 2, ...
        'DisplayName', sprintf('平均 (n=%d)', nValid)) ;
    subplot(2, 1, 2) ; hold on
    plot(tPlot, Fz2_raw_mean, condColors{iCondition}, 'LineWidth', 2, ...
        'DisplayName', sprintf('平均 (n=%d)', nValid)) ;

    figure(figNorm)
    subplot(2, 1, 1) ; hold on
    plot(tPlot, Fz1_norm_mean, condColors{iCondition}, 'LineWidth', 2, ...
        'DisplayName', sprintf('平均 (n=%d)', nValid)) ;
    subplot(2, 1, 2) ; hold on
    plot(tPlot, Fz2_norm_mean, condColors{iCondition}, 'LineWidth', 2, ...
        'DisplayName', sprintf('平均 (n=%d)', nValid)) ;

end  % iCondition
```

最後に、条件ごとの figure を装飾します（タイトルに条件名を入れる点が STEP 8 と異なります）。

```matlab
for iCondition = 1:nCondition
    condName = ConditionNameArray{iCondition} ;
    figRaw   = figRawByCondition(iCondition) ;
    figNorm  = figNormByCondition(iCondition) ;

    % 正規化前（N）の装飾（YLimは自動）
    figure(figRaw)
    subplot(2, 1, 1)
    lineplot(0, 'v', 'k--') ;
    set(gca, 'XLim', plotRange) ;
    xlabel('LEDからの時間 [s]') ; ylabel('Fz [N]') ;
    title(sprintf('Subject %02d  %s条件  プレート１（後ろ足）— 正規化前', iSubject, condName)) ;
    legend('Location', 'northwest') ; grid on

    subplot(2, 1, 2)
    lineplot(0, 'v', 'k--') ;
    set(gca, 'XLim', plotRange) ;
    xlabel('LEDからの時間 [s]') ; ylabel('Fz [N]') ;
    title(sprintf('Subject %02d  %s条件  プレート２（前の足）— 正規化前', iSubject, condName)) ;
    legend('Location', 'northwest') ; grid on

    % 正規化後（BW）の装飾（YLimは固定）
    figure(figNorm)
    subplot(2, 1, 1)
    lineplot(0, 'v', 'k--') ;
    set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]) ;
    xlabel('LEDからの時間 [s]') ; ylabel('Fz [BW]') ;
    title(sprintf('Subject %02d  %s条件  プレート１（後ろ足）— 正規化後', iSubject, condName)) ;
    legend('Location', 'northwest') ; grid on

    subplot(2, 1, 2)
    lineplot(0, 'v', 'k--') ;
    set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]) ;
    xlabel('LEDからの時間 [s]') ; ylabel('Fz [BW]') ;
    title(sprintf('Subject %02d  %s条件  プレート２（前の足）— 正規化後', iSubject, condName)) ;
    legend('Location', 'northwest') ; grid on
end
```

### コードの重要ポイント

**① 条件ごとに figure 番号を切り替える**

```matlab
figRawByCondition  = [6, 7, 8] ;
figRaw = figRawByCondition(iCondition) ;
```

配列 `figRawByCondition` の `iCondition` 番目の要素を取り出すことで、「free なら figure 6、simple なら figure 7、gonogo なら figure 8」という対応関係を作っています。
STEP 8 のように毎回同じ `figure(6)` に描き続けるのではなく、条件ごとに違う figure 番号を選ぶのがポイントです。

**② 描画の順番が「見た目の重なり」を決める**

MATLAB では、後から `plot` した線が前面（手前）に描かれます。
そのため、同じ条件・同じ figure の中で「①個別試行（薄い・細い）→ ②平均（濃い・太い）」の順に描くことで、
平均線が個別試行の線に埋もれずに見えるようになります。条件ごとに figure が分かれているため、STEP 8 の重ね描き版で問題になっていた「他条件の薄線が平均線の上に乗ってしまう」ことも起こりません。

```matlab
for iTrial = 1:nValid          % 先に描く → 背面
    plot(..., 'LineWidth', 0.5)
end
plot(..., 'LineWidth', 2)      % 後に描く → 前面
```

**③ `HandleVisibility off` で凡例を汚さない**

```matlab
plot(..., 'HandleVisibility', 'off') ;
```

個別試行の線1本1本に凡例（legend）の項目を作ってしまうと、試行数だけ凡例が並んで読めなくなります。
`HandleVisibility off` を指定した線は凡例に表示されなくなるため、凡例には平均線の `平均 (n=xx)` の1項目だけが残ります。

**④ `condColorsLight` の作り方**

```matlab
condColorsLight = {[0.7 1 0.7], [0.7 0.7 1], [1 0.7 0.7]} ;
```

MATLAB の色は `[R G B]`（各成分 0〜1）で指定できます。値を 1（白）に近づけるほど薄い色になります。
例えば緑 `[0 1 0]` を `[0.7 1 0.7]` にすると、赤と青の成分が上がって白に近づき、淡い黄緑になります。

### 確認ポイント

- [ ] free / simple / gonogo それぞれについて、正規化前（figure 6〜8）・正規化後（figure 9〜11）の図が個別に開くことを確認する
- [ ] 各 figure の背景に、その条件の薄い色の個別試行波形が何本も重なって見えることを確認する
- [ ] その上に、その条件の濃い太線（平均波形）がはっきり見えることを確認する
- [ ] タイトルに条件名（free / simple / gonogo）が表示され、どの図がどの条件か一目で分かることを確認する
- [ ] 条件によって個別試行のばらつきの大きさが違うか観察する

---

## STEP 10：観察結果を整理して考察する

### 整理すべきこと

`s8_forstudy_scratch8.m` のコード内にコメントとして、以下を記録してください。

```matlab
% ===== 観察メモ =====
% 1. プレート1（青）は ____ 足（軸足 / 踏み込み足）と推測する
%    根拠：
%
% 2. LED点灯後、最初に力が変化し始めるのはプレート ____ である
%    変化が始まる時刻（目測）：t ≈ ____ s
%
% 3. Fz の最大値
%    プレート1 最大値 ≈ ____  BW
%    プレート2 最大値 ≈ ____  BW
%
% 4. 異なる条件（free / simple / gonogo）で違いがあるか？
%    （複数の試行で確認した場合に記録する）
```

### GRFと反応時間の関係（発展的な考察）

これまでの学習（学習用_2〜6）では、**バット先端の速度閾値** でスイング開始を検出しました。
床反力を使うと、**足の力が変化し始めた時刻** を別の「反応の始まり」として定義できます。

| 定義方法             | 検出するもの           | 特徴                           |
| -------------------- | ---------------------- | ------------------------------ |
| バット先端速度の閾値 | バットが動き始めた時刻 | バットの運動を直接反映         |
| 床反力の変化開始     | 足の動き始めた時刻     | 姿勢制御・重心移動の開始を反映 |

> **どちらが「反応」をより正確に捉えているか？**
> これは今後の研究で検討すべきテーマです。
> まずは両方を可視化して、タイミングの違いを目で観察することからはじめましょう。

### 確認ポイント

- [ ] 観察メモをコード内に書き留めた
- [ ] 異なるファイル（別の試行や条件）でも同じコードを試した

---

## 全体の振り返りチェックリスト

- [ ] STEP 1：カレントフォルダとパスを設定し、`s8_forstudy_scratch8.m` を作成した
- [ ] STEP 2：`load_qualisys_mat` でデータを読み込み、`Force1`・`Force2` のサイズを確認した
- [ ] STEP 3：試行全体の Fz 生波形をプロットした（Figure 1）
- [ ] STEP 4：LED基準の時間軸を作り、Fz を LED 基準でプロットした（Figure 2）
- [ ] STEP 5：静止期からの体重推定と BW 正規化を実行した
- [ ] STEP 6：正規化済み Fz を重ねてプロットし、体重移動パターンを観察した（Figure 3, 4）
- [ ] STEP 7：前後方向分力（Fy）を可視化した（Figure 5）
- [ ] STEP 8：条件別平均 GRF を正規化前（Figure 6・N）・正規化後（Figure 7・BW）でプロットし、条件間の違いを観察した
- [ ] STEP 9：各試行を薄く、平均を濃く重ねて描画し、試行間のばらつきを観察した
- [ ] STEP 10：観察メモをコード内に記録した

---

## 困ったときのヒント

### `load_qualisys_mat` でエラーが出るとき

| よくあるエラー                             | 原因                                            | 対処法                                                     |
| ------------------------------------------ | ----------------------------------------------- | ---------------------------------------------------------- |
| `Undefined function 'load_qualisys_mat'` | カレントフォルダが`MATLAB/` になっていない    | MATLABのカレントフォルダを`2026-0604/MATLAB/` に設定する |
| `No such file or directory`              | `folderName` または `fileName` のパスが違う | ファイルブラウザで正確なパスを確認する                     |
| `Index exceeds array dimensions`         | 列番号が範囲外                                  | `size(Data.Force1)` でサイズを確認する                   |

### グラフで Fz がずっと 0 に近いとき

一方の足がプレートから離れているか、プレートの上に乗っていない可能性があります。
別の試行ファイルを試してみてください。

### Fz の最大値が体重より極端に大きいとき（例：体重の2倍以上）

スイング動作中に地面を強く踏み込む（踏み込み動作）と、一瞬だけ体重の1.5〜2倍の力がかかることがあります。
これは生理学的に正常な範囲です。

### tFromLED の作り方が分からないとき

```matlab
% 具体例で理解しよう
% nAnalog = 5000, tCueAnalog = 2000, fsAnalog = 1000 の場合

% サンプル番号の配列
sample_numbers = [1, 2, ..., 2000, ..., 5000]

% tCueAnalog を引く
sample_numbers - tCueAnalog = [-1999, ..., 0, ..., 3000]

% fsAnalog で割る（秒に変換）
tFromLED = [-1.999, ..., 0, ..., 3.000]  % 単位：秒
```

---

*作成日: 2026-06-09*
*更新日: 2026-07-02（STEP 9「各試行を薄く、平均を濃く重ねて描画する」を追加、条件ごとにfigureを分ける構成に更新）*
