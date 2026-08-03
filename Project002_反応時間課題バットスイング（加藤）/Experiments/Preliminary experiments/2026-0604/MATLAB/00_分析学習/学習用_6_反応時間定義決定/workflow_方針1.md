# 実装ワークフロー：方針1（Nasu et al. 2020 完全模倣版）

**作成日**: 2026-06-09
**更新日**: 2026-06-09（体幹補正を追加し Nasu et al. 完全模倣版に変更）
**適用実験**: 追加実験・本実験（`bottom` マーカー＋骨盤マーカーあり）

---

## 方針1 の定義

| 要素 | 定義 |
|------|------|
| **使用データ** | `bottom` マーカー（グリップ端）＋ 骨盤マーカー |
| **速度方向** | **X軸方向の1次元速度**（ホームベース方向 = 投手–捕手方向） |
| **体幹補正** | `bottom` の X軸速度 から 骨盤マーカーの X軸速度 を減算 |
| **閾値** | 被験者ごとの**全試行平均ピーク速度**の **10%** |
| **刺激開始点** | LED電圧が 2V を超えた最初のアナログサンプル |

**Nasu et al. (2020) からの変更点：**
- マーカー位置：手部セグメント → `bottom`（グリップ端マーカー）で代替

---

## 体幹補正とは何か

スイング中、体全体が前進方向へ移動するため、`bottom` マーカーの速度には「スイング自体の速度」と「体幹が前に動く速度」が混在します。

```
（計測された bottom X速度） = （スイングによる手の速度） + （体幹の並進速度）
```

骨盤は体幹の並進運動を代表するため、骨盤X速度を減算することで純粋なスイング動作の速度が得られます。

```
補正済み速度 = bottom の X速度 − 骨盤の X速度
```

Nasu et al. は同じ考え方で「手部速度 − 骨盤速度」を使用しています。

---

## 全体の処理の流れ

```
[STEP 0] bottom・骨盤の X軸速度の波形と補正済み速度を確認する（最初に実施）
[STEP 1] 全試行の補正済みピーク速度を収集する
[STEP 2] 全試行平均ピーク速度から閾値を設定する（10%）
[STEP 3] 1試行でスイング開始フレームを検出する（確認用）
[STEP 4] グラフで視覚的に確認する
[STEP 5] 全試行で RT を算出する
```

---

## STEP 0：波形と補正済み速度を確認する

### なぜ必要か？

- 骨盤マーカーのフィールド名（`M.pelvis` の部分）が実際と一致しているか確認する
- 補正済み速度がスイング開始を正しく表しているか目視で確認する

```matlab
clear ; close all ; clc

iSubject   = 1 ;
iCondition = 2 ;  % simple reaction 条件
iTrial     = 1 ;

dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
load(dataFilePath)
Prm = parameters ;

Data   = DataArray(iTrial, iCondition) ;
fs     = Data.FrameRate ;
[b, a] = butter(2, Prm.Fc/(fs/2)) ;
M      = filt_all_fields(b, a, Data.Markers) ;

% まずフィールド名を確認する（骨盤マーカーの実際の名前を調べる）
disp(fieldnames(M))

% bottom マーカーと骨盤マーカーの X軸速度
bottom      = M.bottom ;
pelvis      = M.pelvis ;          % ← 実際のフィールド名に変更する
velBottom   = diff3p(bottom, 1/fs) ;
velPelvis   = diff3p(pelvis, 1/fs) ;
velBottom_x = velBottom(:, 1) ;   % X軸成分（列1 = ホームベース方向）
velPelvis_x = velPelvis(:, 1) ;   % X軸成分

% 体幹補正済み速度
velCorrected_x = velBottom_x - velPelvis_x ;

% LED タイミング
led        = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

n      = length(velCorrected_x) ;
tArray = (1:n) / fs - tCueMarker / fs ;

figure(10) ; clf
subplot(3,1,1)
plot(tArray, velBottom_x,    'b-') ; yline(0, 'k:')
set(gca, 'xlim', [-0.5, 2.0]) ; ylabel('bottom X速度 [mm/s]')
title('STEP 0：波形確認（補正前後）')

subplot(3,1,2)
plot(tArray, velPelvis_x,    'r-') ; yline(0, 'k:')
set(gca, 'xlim', [-0.5, 2.0]) ; ylabel('骨盤 X速度 [mm/s]')

subplot(3,1,3)
plot(tArray, velCorrected_x, 'g-') ; yline(0, 'k:')
set(gca, 'xlim', [-0.5, 2.0])
ylabel('補正済み X速度 [mm/s]') ; xlabel('Time from LED [s]')
```

### 確認ポイント

- [ ] `fieldnames(M)` で骨盤マーカーのフィールド名を確認し、`M.pelvis` の部分を実際の名前に書き換える
- [ ] 3段のグラフが表示されることを確認する
- [ ] 補正済み速度（緑）がスイング開始で明確に立ち上がることを確認する
- [ ] スイング中に補正済み速度が正方向・負方向どちらに大きくなるか確認する

> **このワークフローでは `abs(velCorrected_x)` を使います。** スイング方向の正負に関わらず「速さ」を正しく扱えるためです。

---

## STEP 1：全試行の補正済みピーク速度を収集する

### なぜ全試行が必要か？

Nasu et al. の閾値は「**各打者の全スイング試行の平均ピーク速度の 10%**」です。1試行のピーク速度ではなく、全試行を平均した値を使います。

```matlab
nTrial = size(DataArray, 1) ;
peakVelCorrected_array = NaN(nTrial, 1) ;

for iTrial = 1:nTrial
    Data_i = DataArray(iTrial, iCondition) ;
    fs_i   = Data_i.FrameRate ;
    [b, a] = butter(2, Prm.Fc/(fs_i/2)) ;
    M_i    = filt_all_fields(b, a, Data_i.Markers) ;

    bottom_i     = M_i.bottom ;
    pelvis_i     = M_i.pelvis ;         % ← STEP 0 で確認したフィールド名に変更する
    velBottom_i  = diff3p(bottom_i, 1/fs_i) ;
    velPelvis_i  = diff3p(pelvis_i, 1/fs_i) ;
    velBottomX_i = velBottom_i(:, 1) ;
    velPelvisX_i = velPelvis_i(:, 1) ;

    velCorrected_i = velBottomX_i - velPelvisX_i ;  % 体幹補正
    peakVelCorrected_array(iTrial) = max(abs(velCorrected_i)) ;
end

meanPeakVelCorrected = mean(peakVelCorrected_array, 'omitnan') ;
fprintf('全試行平均ピーク速度（補正済み）: %.1f mm/s\n', meanPeakVelCorrected) ;
```

### 各コードの意味

| コード | 意味 |
|---|---|
| `velBottomX_i - velPelvisX_i` | 手部X速度から骨盤X速度を引く（体幹の並進成分を除去） |
| `max(abs(velCorrected_i))` | 補正済み速度の絶対値の最大値（符号を問わないピーク速さ） |

### 確認ポイント

- [ ] ループが実行されエラーが出ないことを確認する
- [ ] `meanPeakVelCorrected` がコマンドウィンドウに表示されることを確認する
- [ ] Nasu et al. の平均ピーク速度（0.61 m/s = 610 mm/s）と桁が近いかどうかを確認する

> **Nasu et al. は慣性センサーで手部を計測しており、本研究とは計測方法・マーカー定義が異なるため、値が多少異なっても問題ありません。**

---

## STEP 2：閾値を設定する（平均ピーク速度の 10%）

```matlab
threshold_1 = 0.10 * meanPeakVelCorrected ;
fprintf('方針1 の閾値: %.1f mm/s（平均ピーク速度の 10%%）\n', threshold_1) ;
```

### 確認ポイント

- [ ] `threshold_1` が `meanPeakVelCorrected` のおよそ 10% になっていることを確認する

---

## STEP 3：1試行でスイング開始フレームを検出する（確認用）

```matlab
iTrial = 1 ;
Data   = DataArray(iTrial, iCondition) ;
fs     = Data.FrameRate ;
[b, a] = butter(2, Prm.Fc/(fs/2)) ;
M      = filt_all_fields(b, a, Data.Markers) ;

bottom      = M.bottom ;
pelvis      = M.pelvis ;        % ← フィールド名を確認済みのものに変更する
velBottom   = diff3p(bottom, 1/fs) ;
velPelvis   = diff3p(pelvis, 1/fs) ;
velBottom_x = velBottom(:, 1) ;
velPelvis_x = velPelvis(:, 1) ;
velCorrected_x = velBottom_x - velPelvis_x ;  % 体幹補正

led        = Data.LEDData(:,2) ;
tCueAnalog = find(abs(led) > 2, 1, 'first') ;
tCueMarker = round(tCueAnalog / Data.AnalogFs * fs) ;

% スイング開始検出（LED 点灯後）
searchRange = tCueMarker : length(velCorrected_x) ;
idx1 = find(abs(velCorrected_x(searchRange)) > threshold_1, 1, 'first') ;

if isempty(idx1)
    tOnset1 = NaN ; RT1 = NaN ;
    fprintf('方針1：スイング開始が検出されませんでした\n') ;
else
    tOnset1 = searchRange(1) + idx1 - 1 ;
    RT1     = (tOnset1 - tCueMarker) / fs * 1000 ;
    fprintf('方針1：tSwingOnset = %d フレーム、RT = %.1f ms\n', tOnset1, RT1) ;
end
```

### 各コードの意味

| コード | 意味 |
|---|---|
| `velCorrected_x` | 体幹補正済みの手部X軸速度（= bottom − 骨盤） |
| `abs(velCorrected_x)` | 補正済み速度の絶対値（スイング方向の正負を問わない） |
| `find(..., 1, 'first')` | 条件を最初に満たすフレーム番号のみ返す |

### 確認ポイント

- [ ] `RT1` が表示されることを確認する
- [ ] RT1 がおおよそ 150〜600 ms であることを確認する
- [ ] `tOnset1 > tCueMarker` であることを確認する（LED 点灯後のはず）

---

## STEP 4：グラフで視覚的に確認する

```matlab
figure(11) ; clf
n      = length(velCorrected_x) ;
tArray = (1:n) / fs - tCueMarker / fs ;

plot(tArray, abs(velCorrected_x), 'g-') ; hold on
yline(threshold_1, 'k--') ;

if ~isnan(tOnset1)
    xline((tOnset1 - tCueMarker)/fs, 'r-', 'LineWidth', 1.5)
end

set(gca, 'xlim', [-0.5, 2.0])
xlabel('Time from LED [s]')
ylabel('|補正済みX速度| [mm/s]')
title(sprintf('方針1（Nasu完全模倣）：RT = %.1f ms', RT1))
legend('|補正済みX速度|', '閾値(10%)', 'スイング開始', 'Location', 'northwest')
```

### 確認ポイント

- [ ] 補正済み速度の絶対値波形が表示されることを確認する
- [ ] 赤い縦線（スイング開始）が「速度が閾値を超えた最初のフレーム」に一致することを確認する
- [ ] 縦線がスイング開始よりも前の時刻に来ていないかをグラフで確認する（早すぎる検出はノイズの可能性）

---

## STEP 5：全試行で RT を算出する

```matlab
RT1_array = NaN(nTrial, 1) ;

for iTrial = 1:nTrial
    Data_i = DataArray(iTrial, iCondition) ;
    fs_i   = Data_i.FrameRate ;
    [b, a] = butter(2, Prm.Fc/(fs_i/2)) ;
    M_i    = filt_all_fields(b, a, Data_i.Markers) ;

    bottom_i     = M_i.bottom ;
    pelvis_i     = M_i.pelvis ;      % ← フィールド名を確認済みのものに変更する
    velBottom_i  = diff3p(bottom_i, 1/fs_i) ;
    velPelvis_i  = diff3p(pelvis_i, 1/fs_i) ;
    velBottomX_i = velBottom_i(:, 1) ;
    velPelvisX_i = velPelvis_i(:, 1) ;

    velCorrected_i = velBottomX_i - velPelvisX_i ;   % 体幹補正

    led_i        = Data_i.LEDData(:,2) ;
    tCueAnalog_i = find(abs(led_i) > 2, 1, 'first') ;
    tCueMarker_i = round(tCueAnalog_i / Data_i.AnalogFs * fs_i) ;

    searchRange_i = tCueMarker_i : length(velCorrected_i) ;
    idx_i = find(abs(velCorrected_i(searchRange_i)) > threshold_1, 1, 'first') ;

    if ~isempty(idx_i)
        tOnset_i          = searchRange_i(1) + idx_i - 1 ;
        RT1_array(iTrial) = (tOnset_i - tCueMarker_i) / fs_i * 1000 ;
    end
end

fprintf('=== 方針1 の全試行 RT ===\n') ;
for iTrial = 1:nTrial
    fprintf('試行 %2d: RT = %.1f ms\n', iTrial, RT1_array(iTrial)) ;
end
fprintf('平均 RT（方針1）= %.1f ms\n', mean(RT1_array, 'omitnan')) ;
```

### 確認ポイント

- [ ] 全試行の RT が表示されることを確認する
- [ ] NaN がある試行はグラフで個別確認する（STEP 3〜4 を iTrial を変えて実行）
- [ ] 平均 RT が 150〜600 ms 程度であることを確認する

---

## 全体の振り返りチェックリスト

- [ ] STEP 0：`fieldnames(M)` で骨盤マーカーのフィールド名を確認し、コード内の `M.pelvis` を書き換えた
- [ ] STEP 0：補正前・骨盤・補正後の3段グラフを目視確認した
- [ ] STEP 1：全試行の補正済みピーク速度の平均を算出した
- [ ] STEP 2：閾値（平均ピーク速度の 10%）を設定した
- [ ] STEP 3：1試行でスイング開始フレームと RT を検出した
- [ ] STEP 4：グラフで縦線の位置を目視確認した
- [ ] STEP 5：全試行で RT を算出し、平均値を確認した

---

*作成日: 2026-06-09*
*更新日: 2026-06-09（体幹補正を追加し Nasu et al. 完全模倣版に変更）*