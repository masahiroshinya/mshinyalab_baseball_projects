# 学習ワークフロー：反応時間の定義を決定しよう

## このフォルダの目的

本研究における「反応時間（Reaction Time: RT）」を**正式に定義する**ことが目標です。

---

## 本研究の進め方：2つの方針を並行して検討する

本研究では、実験設計（個別マーカーを使うか、剛体トラッキングのみか）によって採用できる定義が変わります。
そのため、以下の**2つの方針**を並行して整理・検討します。

### 方針1：Nasu et al. (2020) 準拠（個別マーカー版）

バットに**個別の反射マーカー**（`bottom` = グリップ端、`top` = バット先端）を貼付して計測する場合に適用します。

| 要素 | 定義 |
|------|------|
| **使用データ** | `bottom` マーカー（グリップ端の個別反射マーカー） |
| **速度方向** | 3D合成速度（骨盤マーカーがないため体幹補正は省略） |
| **閾値** | 被験者ごとの全試行平均ピーク速度の **10%** |
| **刺激開始点** | LED電圧が 2V を超えた最初のアナログサンプル |
| **適用条件** | 個別マーカーをバットに貼付する実験設計の場合 |

**Nasu et al. からの変更点：**
- マーカーの位置：手部セグメント → `bottom`（グリップ端マーカー）で代替
- 速度方向：投手–捕手方向（1D）→ 3D合成速度（体幹補正なしのため）
- 体幹補正：骨盤速度の減算 → 省略（骨盤マーカーなし）

---

### 方針2：剛体トラッキング専用版

バットを**剛体（rigid body）としてのみトラッキング**する場合に適用します。個別マーカー（`top`/`bottom`）は存在しません。

| 要素 | 定義 |
|------|------|
| **使用データ** | バット剛体の**原点**（Qualisys で設定したグリップ端付近の基準点）の位置座標 |
| **速度方向** | 3D合成速度 |
| **閾値** | 被験者ごとの全試行平均ピーク速度の **10%** |
| **刺激開始点** | LED電圧が 2V を超えた最初のアナログサンプル |
| **適用条件** | バットを剛体としてのみトラッキングする実験設計の場合 |

**方針1からの変更点：**
- 使用データ：`bottom` 個別マーカー → 剛体原点（グリップ端付近に設定）
- 速度の計算方法：同じ（位置の差分から3D合成速度を算出）

> **重要な前提：** Qualisys Track Engineering でバット剛体の**原点をグリップ端付近に設定**しておくことが必要です。
> 原点の位置は実験設計の段階で確認・決定してください。

---

### 2つの方針の比較

| 比較項目 | 方針1（個別マーカー版） | 方針2（剛体専用版） |
|----------|------------------------|---------------------|
| **使用データ** | `bottom` 個別反射マーカー | 剛体原点（グリップ付近に設定） |
| **先行研究との対応** | Nasu et al. (2020) と対応 | 先行研究を調査中 |
| **速度の計算** | 同じ方法（3D合成速度） | 同じ方法（3D合成速度） |
| **閾値** | 平均ピーク速度の10% | 平均ピーク速度の10% |
| **実験設計の条件** | 個別マーカーが必要 | 剛体トラッキングのみでOK |
| **Qualisys設定の依存** | なし（マーカー名で指定） | 剛体原点の位置設定に依存 |

> **方針の選択：** 本実験でバットに個別マーカーを貼付するか、剛体のみでトラッキングするかに応じて、どちらかを採用します。
> 両方のデータが得られる場合は、方針1と方針2で算出した反応時間を比較することができます。

---

## ファイル構成

| ファイル名 | 種類 | 役割 |
|---|---|---|
| `workflow.md`（このファイル） | ドキュメント | 定義決定までの手順を記述 |
| `s6_forstudy_scratch6.m` | スクリプト | 複数の定義をデータで試す練習帳 |
| `s6_literature_notes.md` | メモ | 先行研究の調査結果を記録するファイル |

---

## 全体の流れ

```
[フェーズ1] 先行研究の調査
    ↓ 方針1・方針2それぞれの先行研究を調べる（STEP 1 と STEP 1'）

[フェーズ2] 定義の候補を整理する
    ↓ 調査結果をもとに、方針1・方針2の候補を列挙・比較する

[フェーズ3] 実データで複数の定義を比較する（MATLAB）
    ↓ 複数の定義を実装し、結果の違いを確認する

[フェーズ4] 定義を決定・文書化する
    ↓ 方針1・方針2それぞれの定義を確定し、正式に記録する
```

---

## フェーズ1：先行研究の調査

### 目的

「反応時間」および「スイング開始（運動開始時刻）」の検出方法について、先行研究がどのような定義を採用しているかを調べます。
方針1（個別マーカー版）と方針2（剛体専用版）の両方について調査します。

### 調査すべき論点

反応時間の定義には、以下の2つの要素があります。それぞれについて、先行研究が何を採用しているかを調べましょう。

**論点A：刺激開始点（"何"が起きた瞬間を時間0とするか）**

- LED（光刺激）の点灯タイミング → 本研究の実験装置では電圧で記録済み
- 音刺激の発生タイミング

**論点B：反応開始点（"スイングが始まった"をどう判断するか）**

- 速度閾値（例：ピーク速度の 5%、10%、20%）
- 絶対速度閾値（例：50 mm/s、100 mm/s）
- 加速度が急増し始めた時点
- 使用するマーカーの違い（グリップ端 `bottom` vs バット先端 `top`）

### STEP 1：方針1 の先行研究を探す

以下のキーワードで Google Scholar や CiNii を検索してください。

**英語キーワード（推奨）：**

```
"swing onset" reaction time baseball batting
"movement onset" velocity threshold reaction time
"go/no-go" reaction time sport batting
"choice reaction time" bat swing biomechanics
"simple reaction time" swinging motion onset detection
```

**日本語キーワード：**

```
反応時間 バットスイング 運動開始
スイング開始 閾値 運動学
選択反応課題 バッティング
```

### STEP 1'：方針2 の先行研究を探す

剛体の原点速度によるスイング開始定義を支持する先行研究を探してください。

**検索キーワード（英語）：**

```
"rigid body" bat swing onset reaction time
"rigid body kinematics" batting swing initiation
"6DOF" bat tracking swing onset velocity
bat kinematics rigid body baseball reaction time
```

**確認したいこと：**
1. 剛体のトラッキング（位置センサー、IMU、光学式）でスイング開始を定義している論文があるか
2. そのときの閾値や基準点はどこか
3. 個別マーカーとの比較検証が行われているか

**調査結果は `s6_literature_notes.md` に追記してください。**

### STEP 2：論文から確認すること

論文を読む際に、以下の項目を `s6_literature_notes.md` に記録してください。

```
【確認項目】
1. 著者・年・タイトル
2. 反応時間の定義（刺激開始点は何か）
3. 運動開始の検出方法（速度閾値？加速度？）
4. 使用した閾値の値（例：ピーク速度の10%）
5. 使用したマーカーまたはセンサーの位置
6. サンプリング周波数 [Hz]
7. 被験者（野球経験者か、一般成人か、など）
```

### STEP 3：調査結果を `s6_literature_notes.md` に記録する

このフォルダに `s6_literature_notes.md` を自分で作成し、調べた内容を書いてください。

**テンプレート：**

```markdown
# 先行研究調査メモ：反応時間の定義

## 文献1
- 著者・年：
- タイトル：
- 刺激開始点の定義：
- 運動開始の検出方法：
- 閾値の値：
- 使用マーカー・センサー：
- 備考：

## 文献2
...

## まとめ：よく使われる定義のパターン
...
```

### STEP 1〜3 の確認ポイント

- [ ] Google Scholar や CiNii で方針1の検索（STEP 1）を実行した
- [ ] 方針1の関連論文を最低3本以上読んだ
- [x] `s6_literature_notes.md` に各論文の定義を記録した（Nasu et al. 2020 をAIが読み、記録済み）
- [x] 「よく使われる定義のパターン」をまとめた
- [x] 方針2（剛体速度によるスイング開始定義）の先行研究を検索した（STEP 1' 完了）
- [x] STEP 1' の検索結果を `s6_literature_notes.md` に記録した
  - Punchihewa et al. (2020)：打者側手袋上のIMU、0.1 G 絶対加速度閾値 → **グリップ付近の剛体的動きでスイング開始を定義する根拠**
  - Sarkar & James 他（2011, cricket）：バット直付けセンサー（剛体）からスイング開始を直接特定 → **バット剛体でスイング開始を定義できることの根拠**
  - 10%ピーク速度閾値は Nasu et al. (2020) から引用（Punchihewa は絶対閾値のため）

---

## フェーズ2：定義の候補を整理する

### 目的

フェーズ1の調査結果をもとに、本研究で採用できる定義の候補を列挙・比較します。

### STEP 4：候補の一覧表を作る

`s6_literature_notes.md` に以下のような比較表を追記してください。

**刺激開始点の候補：**

| 候補 | 内容 | 先行研究での使用例 |
|------|------|------------------|
| A. LED電圧onset（現状） | LED信号が閾値（2V）を超えた瞬間 | |
| B. その他 | 調査で見つけたものがあれば追記 | |

**反応開始点の候補：**

| 候補 | 検出方法 | 閾値の値 | 使用マーカー | 先行研究での使用例 |
|------|----------|----------|------------|------------------|
| A. ピーク速度の5%（現状） | 合成速度が閾値を超えた最初のフレーム | peakVel × 0.05 | `top`（バット先端） | |
| B. ピーク速度の10% | 同上 | peakVel × 0.10 | `top` | |
| C. ピーク速度の20% | 同上 | peakVel × 0.20 | `top` | |
| D. 絶対速度閾値 | 同上 | ○○ mm/s（先行研究を参考に） | `top` | |
| E. グリップ端マーカー | 同上 | peakVel × ○% | `bottom`（グリップ端） | |

### STEP 4 の確認ポイント

- [x] 先行研究で使われていた定義を候補A〜に追記した（`s6_literature_notes.md` の比較表に記録済み）
- [x] 各候補のメリット・デメリットを考えた（notes内の「本研究への示唆」参照）
- [x] AIアシスタントに候補を見せ、フィードバックをもらった

---

## フェーズ3：実データで複数の定義を比較する

### 目的

MATLABを使って、フェーズ2で整理した複数の候補を実際のデータに適用し、結果の違いを目で確認します。

### STEP 5：ファイルの準備

`s6_forstudy_scratch6.m` を新規作成し、以下の冒頭部分を書いてください。

```matlab
% s6_forstudy_scratch6.m
% 目的：複数の反応時間定義を実データに適用し、結果を比較する

clear
close all
clc

iSubject   = 1 ;
iCondition = 2 ;  % 2 = simple（simple reaction課題）
iTrial     = 1 ;

dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)

Data = DataArray(iTrial, iCondition) ;

Prm = parameters ;

fs = Data.FrameRate ;
fc = Prm.Fc ;
[b, a] = butter(2, fc/(fs/2)) ;
M = filt_all_fields(b, a, Data.Markers) ;

% バット先端の合成速度
top = M.top ;
velTop = diff3p(top, 1/fs) ;
netVelTop = sum(velTop.^2, 2).^0.5 ;
peakVelTop = max(netVelTop) ;

% グリップ端の合成速度
bottom = M.bottom ;
velBottom = diff3p(bottom, 1/fs) ;
netVelBottom = sum(velBottom.^2, 2).^0.5 ;
peakVelBottom = max(netVelBottom) ;

% LED タイミング
led = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;
```

### STEP 6：複数の閾値でスイング開始フレームを検出する

STEP 5 の続きに追加してください。

```matlab
% ---- 定義ごとのスイング開始フレームを格納する ----

% 定義A：topマーカー、ピーク速度の 5%
threshA = 0.05 * peakVelTop ;
searchRange = tCueMarker : length(netVelTop) ;
idxA = find(netVelTop(searchRange) > threshA, 1, 'first') ;
if isempty(idxA)
    tOnsetA = NaN ;
else
    tOnsetA = searchRange(1) + idxA - 1 ;
end

% 定義B：topマーカー、ピーク速度の 10%
threshB = 0.10 * peakVelTop ;
idxB = find(netVelTop(searchRange) > threshB, 1, 'first') ;
if isempty(idxB)
    tOnsetB = NaN ;
else
    tOnsetB = searchRange(1) + idxB - 1 ;
end

% 定義C：topマーカー、ピーク速度の 20%
threshC = 0.20 * peakVelTop ;
idxC = find(netVelTop(searchRange) > threshC, 1, 'first') ;
if isempty(idxC)
    tOnsetC = NaN ;
else
    tOnsetC = searchRange(1) + idxC - 1 ;
end

% 定義D：bottomマーカー、ピーク速度の 10%（先行研究で根拠が見つかれば値を変更すること）
threshD = 0.10 * peakVelBottom ;
searchRangeB = tCueMarker : length(netVelBottom) ;
idxD = find(netVelBottom(searchRangeB) > threshD, 1, 'first') ;
if isempty(idxD)
    tOnsetD = NaN ;
else
    tOnsetD = searchRangeB(1) + idxD - 1 ;
end
```

> **ポイント**：`定義D` の閾値（`0.10`）は仮の値です。先行研究で根拠となる値が見つかれば、そちらに変更してください。

### STEP 7：各定義で RT を算出して表示する

```matlab
% ---- 各定義でRTを算出する ----
RT_A = (tOnsetA - tCueMarker) / fs * 1000 ;
RT_B = (tOnsetB - tCueMarker) / fs * 1000 ;
RT_C = (tOnsetC - tCueMarker) / fs * 1000 ;
RT_D = (tOnsetD - tCueMarker) / fs * 1000 ;

fprintf('=== 反応時間の比較 ===\n') ;
fprintf('定義A（top、5%%）  : RT = %.1f ms\n', RT_A) ;
fprintf('定義B（top、10%%） : RT = %.1f ms\n', RT_B) ;
fprintf('定義C（top、20%%） : RT = %.1f ms\n', RT_C) ;
fprintf('定義D（bottom、10%%）: RT = %.1f ms\n', RT_D) ;
```

> **`%%` について**：`fprintf` の中では `%` を表示したいときに `%%` と2つ書く必要があります（`%` 1つだと「数値を埋める場所」と解釈されるため）。

### STEP 8：グラフで比較する

```matlab
% ---- グラフで比較する ----
figure(1)
plotTimeRange = [-0.5, 2.0] ;
n = length(netVelTop) ;
tArray = ([1:n] - tCueMarker) / fs ;

% 上段：topマーカーの速度
subplot(2,1,1)
plot(tArray, netVelTop, 'b-') ; hold on
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Bat tip speed [mm/s]')
title('top マーカー（バット先端）の合成速度')

% 各定義のスイング開始縦線を描く
if ~isnan(tOnsetA)
    lineplot((tOnsetA - tCueMarker)/fs, 'v', 'r-')
end
if ~isnan(tOnsetB)
    lineplot((tOnsetB - tCueMarker)/fs, 'v', 'g-')
end
if ~isnan(tOnsetC)
    lineplot((tOnsetC - tCueMarker)/fs, 'v', 'm-')
end
legend('速度', '定義A(5%)', '定義B(10%)', '定義C(20%)', 'Location', 'northwest')

% 下段：bottomマーカーの速度
nB = length(netVelBottom) ;
tArrayB = ([1:nB] - tCueMarker) / fs ;

subplot(2,1,2)
plot(tArrayB, netVelBottom, 'b-') ; hold on
set(gca, 'xlim', plotTimeRange)
xlabel('Time from LED [s]')
ylabel('Grip end speed [mm/s]')
title('bottom マーカー（グリップ端）の合成速度')

if ~isnan(tOnsetD)
    lineplot((tOnsetD - tCueMarker)/fs, 'v', 'k-')
end
legend('速度', '定義D(bottom,10%)', 'Location', 'northwest')
```

### STEP 8 の確認ポイント

- [ ] コードを実行してエラーが出ないことを確認する
- [ ] コマンドウィンドウに4つの定義のRTが表示されることを確認する
- [ ] Figure 1 に2つのグラフが表示されることを確認する
- [ ] 縦線の位置（スイング開始の検出タイミング）が定義によって異なることを確認する
- [ ] `top` と `bottom` でどちらの速度が先に上がり始めるかを確認する

### STEP 9：複数の試行で比較する（発展）

1試行だけでは定義の良し悪しを判断しにくいことがあります。
余裕があれば、`iTrial` の値を変えて複数の試行で確認してみましょう。

```matlab
% コマンドウィンドウで試す例
for iTrial = 1:5
    Data = DataArray(iTrial, iCondition) ;
    % ... （同様の処理）
end
```

---

## フェーズ4：定義を決定・文書化する

### 目的

フェーズ1〜3の結果をもとに、本研究で使う反応時間の定義を1つに決め、正式に記録します。

### STEP 10：定義を決定するための判断基準

以下の観点から、最も適切な定義を選んでください。

| 判断基準 | 内容 |
|---|---|
| **先行研究との整合性** | 同様の研究で使われている定義に合わせると、結果の比較・考察がしやすい |
| **検出の安定性** | 閾値が低すぎるとノイズを拾いやすく、高すぎるとスイング開始の検出が遅れる |
| **生理学的妥当性** | 「スイングが始まった」という現象を最もよく表しているか |
| **再現性** | 同じデータを再分析したとき、同じ結果が得られるか |

### STEP 11：定義を `s6_literature_notes.md` に記録する

調査・比較の結果を踏まえ、以下のテンプレートで決定事項を記録してください。

```markdown
## 本研究における反応時間の定義（決定版）

### 決定した定義
- **刺激開始点**：（例：Go LED が 2V を超えた最初のアナログサンプル）
- **反応開始点**：（例：`bottom` マーカーの合成速度がピーク速度の 10% を超えた最初のフレーム）
- **算出式**：RT [ms] = (tSwingOnset - tCueMarker) / fs × 1000

### 決定の根拠
- 先行研究：（採用した定義の出典を書く）
- 実データでの確認結果：（グラフで確認した内容を書く）

### 採用しなかった定義とその理由
- 定義A（top、5%）：（採用しなかった理由）
- ...
```

### STEP 12：`parameters.m` に反映する

定義が確定したら、`parameters.m` にパラメータとして追記することをAIアシスタントに依頼してください。

追記する内容の例（確定した定義に応じて変更してください）：

```matlab
% 反応時間算出パラメータ
Prm.RT.ThresholdRatio = 0.10 ;       % スイング開始閾値（ピーク速度に対する割合）
Prm.RT.OnsetMarker    = 'bottom' ;   % スイング開始検出に使用するマーカー
```

> **注意**：`parameters.m` の変更はAIアシスタントに依頼してください（自分で書き換える場合は慎重に）。

### STEP 13：`m3_analyze_single_trial.m` への反映を確認する

定義が確定したら、本番スクリプト `m3_analyze_single_trial.m` の実装が確定した定義と一致しているか確認し、必要であればAIアシスタントに修正を依頼してください。

### STEP 10〜13 の確認ポイント

- [ ] 定義を1つに決めた
- [ ] `s6_literature_notes.md` に決定した定義と根拠を記録した
- [ ] AIアシスタントに `parameters.m` への反映を依頼した
- [ ] `m3_analyze_single_trial.m` の実装が確定した定義と一致していることを確認した

---

## 全体の振り返りチェックリスト

- [ ] フェーズ1（方針1）：Nasu et al. をもとにした先行研究調査（Nasu et al. 1本のみ完了、他論文は未実施）
- [x] フェーズ1（方針2）：剛体速度によるスイング開始定義の先行研究を検索した（STEP 1' 完了）
- [x] フェーズ2：定義の候補を整理し、方針1・方針2の比較表を作成した
- [ ] フェーズ3：`s6_forstudy_scratch6.m` を作成し、複数の定義で RT を比較した
- [ ] フェーズ4：方針1 または 方針2（あるいは両方）の定義を確定し、文書化した

---

## 困ったときのヒント

### 先行研究が見つからないとき

- 「バットスイング 反応時間」で見つからない場合は、より広いキーワードで探してみましょう。
  - 「上肢の到達運動（reaching movement）の運動開始」に関する研究も参考になります。
  - クリケット・テニスなど他のラケット・バット競技の研究も参考になります。
- AIアシスタントに「どんな論文を探せばよいか」を相談してみましょう。

### グラフの見方が分からないとき

- `top` と `bottom` の速度波形を見比べ、「どちらが先に動き始めるか」を確認してください。
- 速度の立ち上がりがはっきりしているほど、閾値による検出が安定しやすいです。

### 閾値をどの値にすればよいか分からないとき

- 先行研究で使われている値を優先してください。
- 同じ先行研究が複数の値を使っていたり、研究間でばらつきがある場合は、実データでの見た目（グラフ）も参考にしてください。

---

*作成日: 2026-06-08*
