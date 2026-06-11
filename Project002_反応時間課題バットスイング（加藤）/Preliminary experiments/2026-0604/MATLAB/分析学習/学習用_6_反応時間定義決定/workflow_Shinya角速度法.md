# 学習ワークフロー：Shinya 法（角速度）による反応時間算出

## このフォルダの目的

Shinya et al. (2020) が提案した**バット長軸の角速度**を使って、スイング開始タイミングを検出し、反応時間を算出する方法を学びます。

前回（学習用_2_反応時間算出）では「バット先端の線速度」を使いました。
今回は「バットが回転する速さ（角速度）」を使う点が新しいポイントです。

| ファイル名                                     | 種類       | 役割                                                |
| ---------------------------------------------- | ---------- | --------------------------------------------------- |
| `s6_forstudy_scratch6_rt_angular_velocity.m` | スクリプト | 角速度を使った RT 算出を1試行で手を動かして確かめる |

---

## 先行研究との対応

| 要素                   | 本スクリプトの定義                        | 根拠                 |
| ---------------------- | ----------------------------------------- | -------------------- |
| スイング開始の検出指標 | バット長軸の角速度 ω [deg/s]             | Shinya et al. (2020) |
| スイング開始の閾値     | 300 deg/s（絶対値）                       | Shinya et al. (2020) |
| 反応時間の定義枠組み   | LED キューからスイング開始までの時間 [ms] | Nasu et al. (2025)   |

> 詳しい文献根拠は `s6_rigid_body_RT_survey.md` の「検討①・検討②」を参照すること。

---

## 全体の処理の流れ

```
[STEP 0] カレントフォルダと新規ファイルの準備
[STEP 1] データを読み込む
[STEP 2] マーカーをフィルタリングする
[STEP 3] バット長軸の単位ベクトルを計算する
[STEP 4] 単位ベクトルの時間微分から角速度を計算する
[STEP 5] LED タイミングを取得する
[STEP 6] 角速度が閾値（300 deg/s）を超えた最初のフレームを探す
[STEP 7] 反応時間を算出する
[STEP 8] グラフで視覚的に確認する
[STEP 9] Go 試行と NoGo 試行の両方で確認する
```

---

## STEP 0：カレントフォルダと新規ファイルの準備

MATLABのカレントフォルダを `Preliminary experiments/2026-0604/MATLAB/` に設定し、
このフォルダ（`学習用_6_反応時間定義決定/`）をパスに追加します。

```matlab
% コマンドウィンドウで実行する
addpath('分析学習/学習用_6_反応時間定義決定')
```

次に、`学習用_6_反応時間定義決定/` フォルダに新規MATLABスクリプトを作成します。

ファイル名：`s6_forstudy_scratch6_rt_angular_velocity.m`

先頭に以下を書いてください：

```matlab
% s6_forstudy_scratch6_rt_angular_velocity.m
%
% 【目的】
%   Shinya et al. (2020) の角速度法によるスイング開始検出を
%   1試行分のデータで試す。
%
%   スイング開始の定義:
%     バット長軸の角速度 > 300 deg/s
%     （Shinya et al., 2020, PMC7077830）

clear
close all
clc
```

### 確認ポイント

- [X] MATLABのカレントフォルダが `MATLAB/` になっていることを確認する
- [X] `s6_forstudy_scratch6_rt_angular_velocity.m` が新規作成できていることを確認する

---

## STEP 1：データを読み込む

```matlab
iSubject   = 1 ;
iCondition = 3 ;   % 1=free, 2=simple, 3=gonogo

% まず最初は iTrial = 1 の試行で動作確認する
iTrial = 1 ;

dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;

Prm = parameters ;
fs  = Data.FrameRate ;
fprintf('サンプリング周波数: %d Hz\n', fs) ;
```

次に、`Data.Markers` にどんなマーカーが入っているかを確認します。

```matlab
% マーカー一覧を表示する
disp('=== Data.Markers のフィールド名 ===')
disp(fieldnames(Data.Markers))
```

### 確認ポイント

- [X] `Data` が読み込まれることを確認する
- [X] `fs` の値をコマンドウィンドウで確認する（例：200 Hz など） = 250 Hz
- [X] フィールド名の一覧に `bottom` と `top` が含まれることを確認する
- [X] `bottom` が含まれない場合は、グリップ端に相当するマーカー名を特定して控えておく：`________`

---

## STEP 2：マーカーをフィルタリングする

### なぜフィルタリングが必要か？

角速度は位置の「方向ベクトルを微分したもの」です。
微分をするとノイズが増幅されるため、微分の前に必ずフィルタリングが必要です。

```
位置 x(t)  →  1回微分  →  速度 v(t)
           ノイズが増幅される
```

今回は方向ベクトルを1回微分して角速度を求めます。
事前にローパスフィルタ（Butterworth フィルタ）でノイズを除去します。

### NaN 補間（フィルタリング前の前処理）

`filtfilt` はデータに NaN（欠損値）が含まれるとエラーになります。
`x1_import_data` のクリーニング処理では 10 サンプルを超える連続欠損は補間されずに残るため、
フィルタリングの前に残存 NaN を線形補間で埋める必要があります。

```matlab
% NaN補間（フィルタリング前の前処理）
fields = fieldnames(Data.Markers) ;
for i = 1:numel(fields)
    f = fields{i} ;
    x = Data.Markers.(f) ;          % [nFrames × 3]
    t = (1:size(x,1))' ;
    for col = 1:size(x,2)
        nanIdx = isnan(x(:,col)) ;
        if any(nanIdx) && any(~nanIdx)
            x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear') ;
        end
    end
    Data.Markers.(f) = x ;
end
```

```matlab
fc = Prm.Fc ;   % カットオフ周波数（parameters.m で設定: 30 Hz）
[b, a] = butter(2, fc / (fs / 2)) ;
M = filt_all_fields(b, a, Data.Markers) ;
```

### 確認ポイント

- [ ] NaN補間ブロックを実行してもエラーが出ないことを確認する
- [ ] `filt_all_fields` 関数を使ってフィルタリングできることを確認する（エラーが出ない）
- [ ] `M` 構造体に `bottom` と `top` フィールドが含まれることを確認する

---

## STEP 3：バット長軸の単位ベクトルを計算する

### 「単位ベクトル」とは？

ベクトルは「向き」と「大きさ」の2つの情報を持ちます。
「単位ベクトル」は大きさを 1 に正規化したベクトルで、**向きだけの情報**を持ちます。

```
e_L = v_long / ||v_long||
      ↑向きと大きさ  ↑大きさ（ノルム）で割ると「向き」だけになる
```

バット長軸の単位ベクトル `e_L` は「バットが今どの方向を向いているか」を表します。

```matlab
r_bottom = M.bottom ;   % [nFrames × 3]  グリップ端の位置 [mm]
r_top    = M.top ;      % [nFrames × 3]  バット先端の位置 [mm]

% bottom → top の方向ベクトル
v_long = r_top - r_bottom ;                  % [nFrames × 3]

% ノルム（大きさ）の計算
v_long_norm = sum(v_long.^2, 2).^0.5 ;      % [nFrames × 1]

% 単位ベクトル（正規化）
e_long = v_long ./ v_long_norm ;             % [nFrames × 3]
```

### `sum(v_long.^2, 2).^0.5` の意味

これはベクトルのノルム（大きさ）を計算する式です。

```
||v|| = sqrt(vx² + vy² + vz²)
```

MATLABでは：

| コード          | 意味                                                    |
| --------------- | ------------------------------------------------------- |
| `v_long.^2`   | 各要素を2乗する（x², y², z² を全フレーム同時に計算） |
| `sum(..., 2)` | 行方向に合計する（各フレームで x²＋y²＋z² を計算）   |
| `.^0.5`       | 0.5乗 = 平方根を取る                                    |

### `./ v_long_norm` の意味

`e_long = v_long ./ v_long_norm` では、
`[nFrames × 3]` の配列を `[nFrames × 1]` の列ベクトルで割っています。

MATLABのブロードキャスト（自動拡張）により、各フレームの x, y, z の3成分が
全て同じノルムで割られます。

**具体例（1フレーム分）：**

```
v_long      = [100, 0, 500]    （長軸ベクトル）
v_long_norm = sqrt(100² + 0² + 500²) = sqrt(260000) ≈ 509.9

e_long = [100/509.9, 0/509.9, 500/509.9]
       = [0.196, 0, 0.981]    ← ノルムが 1 になっている
```

### 確認ポイント

- [ ] 以下の検証コードを実行し、`e_long` のノルムが 1.0 に近いことを確認する

```matlab
% 検証コード: e_long のノルムが 1.0 であることを確認
e_long_norm_check = sum(e_long.^2, 2).^0.5 ;
fprintf('e_long ノルムの最大値: %.6f\n', max(e_long_norm_check)) ;
fprintf('e_long ノルムの最小値: %.6f\n', min(e_long_norm_check)) ;
```

- [ ] 最大値・最小値が 1.000000 に近い値（例: 0.999999〜1.000001）であることを確認する

---

## STEP 4：単位ベクトルの時間微分から角速度を計算する

### なぜ単位ベクトルの微分が角速度になるのか？

**直感的な説明（時計の針のたとえ）**

時計の長針は「1分間に360度」回転します。
針の先端（単位ベクトル `e`）は1秒間に 6度 ÷ 1秒 = 6 deg/s の速さで動きます。

一般に、単位ベクトル `e` が角速度 ω [rad/s] で回転しているとき、
その先端の移動速さは：

```
||de/dt|| = ω × 1 = ω   [rad/s]
                ↑単位ベクトルなので半径 = 1
```

つまり、**単位ベクトルの時間微分のノルム = 角速度の大きさ** になります。

**数式での確認（参考）：**

```
e·e = 1 の両辺を時間微分すると
  2(e · de/dt) = 0
  → de/dt は e と常に垂直

角速度ベクトル ω を使うと   de/dt = ω × e
両辺のノルムをとると          ||de/dt|| = ||ω × e|| = ||ω|| sin(θ)

スイング時、ω（回転軸）と e（バット長軸）はほぼ垂直 → sin(θ) ≈ 1

したがって  ||de/dt|| ≈ ||ω_⊥||  [rad/s]   （長軸に垂直な角速度成分）
```

バットスイングの主運動は「バットを振る（弧を描く）」動きなので、
この「長軸に垂直な角速度成分」がスイング開始を検出するのに適した指標です。

```matlab
% 単位ベクトルの時間微分（diff3p は3点中心差分法）
de_long = diff3p(e_long, 1/fs) ;        % [nFrames × 3]

% 各フレームでの大きさ（= 角速度の近似値）
omega_rad = sum(de_long.^2, 2).^0.5 ;  % [nFrames × 1]  [rad/s]

% ラジアン/秒 → 度/秒 に変換
omega_deg = omega_rad * (180 / pi) ;   % [nFrames × 1]  [deg/s]
```

### `diff3p` について

`diff3p(data, h)` は**3点中心差分法**という数値微分の手法です。
`h = 1/fs` はサンプリング間隔（秒）です。

```
中央のフレームでの微分値 ≈ (1フレーム後 − 1フレーム前) / (2 × サンプリング間隔)
```

これは前進差分（後ろの値だけ使う方法）よりもノイズに強い手法です。

### 単位の確認

| 変数          | 単位               | 補足                   |
| ------------- | ------------------ | ---------------------- |
| `e_long`    | 無次元（長さ1）    | 単位ベクトル           |
| `de_long`   | rad/s（e_long/秒） | e_long の変化速度      |
| `omega_rad` | rad/s              | 角速度（ラジアン毎秒） |
| `omega_deg` | deg/s              | 角速度（度毎秒）       |

**ラジアンから度への変換：**

```
1 ラジアン = 180 / π ≈ 57.3 度
x [rad/s] × (180 / π) = y [deg/s]
```

### 確認ポイント

- [ ] 以下のコードで最大値を確認する

```matlab
fprintf('omega_deg の最大値: %.1f deg/s\n', max(omega_deg)) ;
```

- [ ] スイング試行で最大値が 300 deg/s を大きく超えることを確認する（例：1000 deg/s 以上）
- [ ] `omega_deg` が `[nFrames × 1]` の列ベクトルであることを確認する

---

## STEP 5：LED タイミングを取得する

（学習用_2 の復習）

```matlab
led        = Data.LEDData(:, 2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

if isempty(tCueAnalog)
    error('LED タイミングが検出されませんでした') ;
end

if led(tCueAnalog) > 0
    cueText = 'Go' ;
else
    cueText = 'NoGo' ;
end

fprintf('キュー種類: %s\n', cueText) ;
fprintf('LED フレーム: %d フレーム目\n', tCueMarker) ;
```

### 確認ポイント

- [ ] `tCueMarker` の値が表示されることを確認する
- [ ] `cueText` が `'Go'` または `'NoGo'` になることを確認する

---

## STEP 6：角速度が閾値（300 deg/s）を超えた最初のフレームを探す

### 線速度法（前回）との比較

|            | 線速度法（学習用_2）                  | 角速度法（今回）                |
| ---------- | ------------------------------------- | ------------------------------- |
| 指標       | バット先端速度 [mm/s]                 | バット長軸角速度 [deg/s]        |
| 閾値の種類 | **相対閾値**（ピーク速度の 5%） | **絶対閾値**（300 deg/s） |
| 閾値の根拠 | 被験者ごとのデータから算出            | 先行研究（Shinya 2020）の定義   |

今回は**絶対閾値**なので、被験者ごとのピーク値を先に計算する必要がありません。

```matlab
THRESHOLD_OMEGA = 300 ;   % [deg/s]（Shinya et al., 2020）

nFrames     = length(omega_deg) ;
searchRange = tCueMarker : nFrames ;

idxAbove = find(omega_deg(searchRange) > THRESHOLD_OMEGA, 1, 'first') ;

if isempty(idxAbove)
    tSwingOnset = NaN ;
    fprintf('スイング開始が検出されませんでした\n') ;
else
    tSwingOnset = searchRange(1) + idxAbove - 1 ;
    fprintf('スイング開始: %d フレーム目\n', tSwingOnset) ;
end
```

### `searchRange` のインデックス変換（復習）

```
searchRange = [tCueMarker, tCueMarker+1, ..., nFrames]

find で得た idxAbove は「searchRange の中での番号」なので、
元のフレーム番号に戻す計算が必要：

  tSwingOnset = searchRange(1) + idxAbove - 1
              = tCueMarker    + idxAbove - 1
```

### 確認ポイント

- [ ] `tSwingOnset` の値が表示されることを確認する（Go 試行の場合）
- [ ] `tSwingOnset > tCueMarker` であることを確認する（スイング開始は LED 点灯後のはず）
- [ ] `omega_deg(tSwingOnset)` の値が 300 deg/s に近いことを確認する

---

## STEP 7：反応時間を算出する

$$
RT [\text{ms}] = \frac{t_{\text{SwingOnset}} - t_{\text{CueMarker}}}{f_s} \times 1000
$$

```matlab
if isnan(tSwingOnset)
    RT = NaN ;
    fprintf('RT: 未算出（スイング未検出）\n') ;
else
    RT = (tSwingOnset - tCueMarker) / fs * 1000 ;   % [ms]
    fprintf('RT = %.1f ms  (CueText: %s)\n', RT, cueText) ;
end
```

### 単位の変換

| 計算式の部分                 | 意味                                           |
| ---------------------------- | ---------------------------------------------- |
| `tSwingOnset - tCueMarker` | フレーム数の差                                 |
| `/ fs`                     | フレーム数 ÷ サンプリング周波数 = 時間差 [秒] |
| `* 1000`                   | 秒 → ミリ秒に変換（1秒 = 1000ミリ秒）         |

**例：**

```
tSwingOnset = 620 フレーム
tCueMarker  = 500 フレーム
fs          = 200 Hz

RT = (620 - 500) / 200 × 1000
   = 120 / 200 × 1000
   = 0.6 × 1000
   = 600 ms
```

### ヒトの反応時間の目安

| 刺激の種類                 | 典型的な反応時間 |
| -------------------------- | ---------------- |
| 光刺激（視覚）             | 150〜300 ms      |
| 音刺激（聴覚）             | 100〜200 ms      |
| バットスイング（単純反応） | 200〜400 ms      |
| バットスイング（Go/NoGo）  | 300〜600 ms      |

### 確認ポイント

- [ ] `RT` の値が表示されることを確認する
- [ ] RT がおおよそ 150〜600 ms 程度であることを確認する
- [ ] 値が極端に小さい（例: 50 ms 以下）または大きい（例: 1000 ms 以上）場合は、データやフレームレートを見直す

---

## STEP 8：グラフで視覚的に確認する

```matlab
nFrames  = length(omega_deg) ;
tArray   = ([1:nFrames] - tCueMarker) / fs ;
plotXLim = [-1, 3] ;

figure(1) ;
clf

% 上段: 角速度の時系列
subplot(3, 1, [1 2])
plot(tArray, omega_deg, 'b-', 'LineWidth', 1.2)
hold on

% 閾値の横線
yline(THRESHOLD_OMEGA, 'r--', sprintf('%d deg/s', THRESHOLD_OMEGA)) ;

% スイング開始の縦線
if ~isnan(tSwingOnset)
    tSO_sec = (tSwingOnset - tCueMarker) / fs ;
    lineplot(tSO_sec, 'v', 'r-') ;
end

set(gca, 'XLim', plotXLim) ;
xlabel('LED キューからの時間 (s)') ;
ylabel('角速度 (deg/s)') ;

if ~isnan(RT)
    title(sprintf('RT = %.1f ms  [%s]  |  Shinya 法（閾値 %d deg/s）', ...
          RT, cueText, THRESHOLD_OMEGA)) ;
else
    title(sprintf('スイング未検出  [%s]', cueText)) ;
end
grid on

% 下段: LED 信号
subplot(3, 1, 3)
nAnalog      = size(Data.LEDData, 1) ;
tArrayAnalog = ([1:nAnalog] - tCueAnalog) / Data.AnalogFs ;
plot(tArrayAnalog, Data.LEDData)
set(gca, 'XLim', plotXLim) ;
xlabel('LED キューからの時間 (s)') ;
ylabel('LED 信号 (V)') ;
grid on
```

### グラフの読み方

```
角速度
(deg/s)
│                          ●●●●●
│                       ●●●
│ 300 ─── ─── ─── ─── ●          ← 閾値（300 deg/s）の赤い破線
│                   ●
│ ────────────── ●                ← tSwingOnset（赤い縦線）
│                ↑
│           LED 点灯（t = 0 s）
0──────────────────────────── 時間 (s)
```

- 赤い破線（横線）：300 deg/s の閾値
- 赤い縦線：スイング開始タイミング（角速度が閾値を初めて超えた瞬間）
- タイトルに RT の値が表示される

### 確認ポイント

- [ ] 図が表示されることを確認する
- [ ] 角速度波形が LED 点灯後（t > 0 秒）に上昇していることを確認する
- [ ] 赤い破線（300 deg/s）と赤い縦線（スイング開始）が表示されることを確認する
- [ ] 縦線の位置が角速度の立ち上がりと一致しているかを目視確認する
- [ ] 縦線が LED 点灯前（t < 0）に来ていないことを確認する

---

## STEP 9：Go 試行と NoGo 試行の両方で確認する

角速度法が Go/NoGo を正しく判別できているか確認します。
`iTrial` の値を変えながら、複数の試行で動作を確認してください。

### Go 試行で確認する

- [ ] 複数の Go 試行で実行し、`tSwingOnset` が NaN でないことを確認する
- [ ] RT が 150〜600 ms 程度であることを確認する
- [ ] グラフで角速度が 300 deg/s を明確に超えていることを確認する

### NoGo 試行で確認する

LED 信号（グラフ下段）の電圧が負（－側）の試行が NoGo です。

- [ ] NoGo 試行では `tSwingOnset = NaN`（スイング未検出）になることを確認する
- [ ] コマンドウィンドウに「スイング開始が検出されませんでした」と表示されることを確認する

> **もし NoGo 試行で 300 deg/s を超えてしまう場合：**
> 閾値 300 deg/s が本実験データには合っていない可能性があります。
> その場合は以下を確認してください：
>
> ```matlab
> % Go 試行と NoGo 試行それぞれの角速度最大値を比較する
> fprintf('このデータの角速度最大値: %.1f deg/s\n', max(omega_deg)) ;
> ```
>
> データをもとに適切な閾値を検討し、`s6_rigid_body_RT_survey.md` に記録すること。

---

## 全体の振り返りチェックリスト

- [ ] STEP 0: ファイルを新規作成し、カレントフォルダを設定した
- [ ] STEP 1: データの読み込みができた。`bottom` と `top` マーカーを確認した
- [ ] STEP 2: `filt_all_fields` でマーカーをフィルタリングした
- [ ] STEP 3: `e_long`（長軸単位ベクトル）を計算し、ノルムが 1.0 であることを確認した
- [ ] STEP 4: `omega_deg` を計算し、最大値がスイング試行で 300 deg/s を大きく超えることを確認した
- [ ] STEP 5: `tCueMarker` と `cueText` が正しく取得された
- [ ] STEP 6: Go 試行でスイング開始が検出され、`tSwingOnset > tCueMarker` であることを確認した
- [ ] STEP 7: RT が 150〜600 ms 程度であることを確認した
- [ ] STEP 8: グラフで縦線の位置を目視確認した
- [ ] STEP 9: 複数の Go 試行と NoGo 試行で動作を確認した

---

## 困ったときのヒント

### `bottom` マーカーが見当たらない場合

```matlab
fieldnames(Data.Markers)
```

でマーカー一覧を確認し、グリップ端に相当するマーカー名を特定してください。
見つかったマーカー名に `r_bottom = M.bottom ;` の `bottom` を書き換えます。

### NoGo 試行でスイング開始が検出されてしまう場合

1. Go 試行と NoGo 試行の角速度波形を見比べる
2. 両者の間に差があるか（Go は 1000 deg/s 以上まで上がるが NoGo は 300 deg/s 付近にとどまるか）を確認する
3. 分離できる最適な閾値を検討し、`s6_rigid_body_RT_survey.md` に記録する

### 角速度の波形がノイズっぽい（ギザギザが多い）場合

カットオフ周波数 `Prm.Fc`（デフォルト: 30 Hz）を下げると波形が滑らかになります。
ただし低くしすぎると波形が鈍くなるので、10〜20 Hz の範囲で試してください。
変更する場合は `parameters.m` ではなく、スクリプト内で上書き設定してください：

```matlab
fc = 15 ;   % 例: 30 Hz → 15 Hz に下げる
```

### 変数の中身を確認したいときは

```matlab
omega_deg(tSwingOnset)          % スイング開始フレームの角速度値を確認
omega_deg(tCueMarker)           % LED 点灯時点の角速度値を確認
max(omega_deg)                  % 角速度の最大値を確認
```

### 関数の使い方が分からないときは

```matlab
help diff3p
help find
help butter
```

---

*作成日: 2026-06-11*
*参照文献: Shinya et al. (2020) PMC7077830; Nasu et al. (2025) PMC11822940*
