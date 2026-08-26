% untitled.m
%
% 1試行の読み込み → RT / MT / 最大速度 / 平均加速度の算出 → 作図
%
% RT 検出は Fx（前後方向の合成床反力）のピーク相対閾値による。
% 検証の経緯と、この方式を採る理由は 技術説明.md §3 を参照。
%   - dFx/dt に閾値をかける方式は、探索窓内で正にならない試行で閾値が負になり
%     破綻する（RT<150ms が 59%）。微分によるノイズ増幅が根本原因。
%   - Fx 基準・比率 0.20・持続 20 ms で RT<150ms は 4.9% まで下がり、
%     被験者内 SD が最小、条件順序も単調になる。
%
% 2026-08-26

clear
close all
clc

%% ---- 1. データの場所と、読みたい試行を指定 ----
AnalysisDir = fullfile('..', '..', 'Experiments', 'Main experiments', '03_Analysis') ;

iSubject   = 5 ;   % 被験者番号
iCondition = 2 ;   % 1=free, 2=simple, 3=gonogo, 4=gostop
iTrial     = 7 ;   % DataArray の行番号（ファイル名上の試行番号とは別物）

% ---- 分析パラメータ（ここだけ変えれば挙動が変わるようにまとめる）----
Prm.CueGoThresholdV  =  2 ;    % Go 判定（緑LED = 正電圧）の電圧閾値 [V]
Prm.CueNegThresholdV = -1 ;    % NoGo / Stop 判定（赤LED = 負電圧）の電圧閾値 [V]
Prm.ForceFc          = 50 ;    % 床反力のローパス遮断周波数 [Hz]
Prm.FootContactN     = 50 ;    % 前足接地とみなす Fz2 の閾値 [N]
Prm.BaseSec          = 0.5 ;   % ベースライン窓（キュー直前）[s]
Prm.RatioFx          = 0.20 ;  % RT 閾値＝ベースライン + 比率 ×（窓内ピーク − ベースライン）
Prm.DurMs            = 20 ;    % 閾値超えの持続時間 [ms]

%% ---- 2. 被験者1人分の .mat を読み込む ----
% x3_DataChecked/DataXX.mat の中身は DataArray（試行 × 条件 の構造体配列）
S = load( fullfile(AnalysisDir, 'x3_DataChecked', sprintf('Data%02d.mat', iSubject)) ) ;
DataArray = S.DataArray ;

%% ---- 3. 1試行だけ取り出す ----
Data = DataArray(iTrial, iCondition) ;

if isempty(Data.ErrorCode) || isequal(Data.ErrorCode, 3)
    error('この要素にはデータがありません（条件ごとの試行数の差を埋める要素）') ;
end

%% ---- 4. よく使う中身を変数に出しておく ----
fs       = Data.FrameRate ;   % マーカー系のサンプリング周波数 [Hz]
analogFs = Data.AnalogFs ;    % アナログ系（LED・床反力）の周波数 [Hz]
Markers  = Data.Markers ;     % 構造体。Markers.top などが [nFrame x 3] [mm]
ledData  = Data.LEDData ;     % [nAnalog x 2] ch1, ch2
force1   = Data.Force1 ;      % 後ろ足 [nAnalog x 3] [N]
force2   = Data.Force2 ;      % 前足   [nAnalog x 3] [N]

% ---- アナログ末尾の NaN を落とす ----
%  QTM の記録終端に NaN が1サンプル残っている試行がある（全300試行中15件）。
%  filtfilt は NaN を受け付けずに mustBeFinite で停止するため、ここで切る。
isBadSample = any(isnan(ledData), 2) | any(isnan(force1), 2) | any(isnan(force2), 2) ;
lastValid   = find(~isBadSample, 1, 'last') ;

if isempty(lastValid) || lastValid < 100
    error('有効なアナログデータがありません') ;
end
if lastValid < numel(isBadSample)
    fprintf('アナログ末尾の %d サンプルを NaN のため除外しました\n', ...
        numel(isBadSample) - lastValid) ;
end

ledData = ledData(1:lastValid, :) ;
force1  = force1( 1:lastValid, :) ;
force2  = force2( 1:lastValid, :) ;

nFrames = size(Markers.top, 1) ;
nAnalog = size(ledData, 1) ;          % length ではなく size(...,1)：行数であることを明示する
t       = (0:nFrames-1)' / fs ;       % 試行先頭を 0 とする時刻 [s]
tAnalog = (0:nAnalog-1)' / analogFs ;

%% ---- 5. キューの検出と試行タイプの判定 ----
%  緑LED（Go）= 正電圧、赤LED（NoGo / Stop）= 負電圧。
%  NoGo 試行は正のパルスが出ないので、ここで分類しておかないと
%  「LED が見つからない」というエラーになる（gonogo の各被験者5試行が該当）。
tGoStim  = find(ledData(:,2) >  Prm.CueGoThresholdV,  1, 'first') ;
tNegStim = find(ledData(:,2) <  Prm.CueNegThresholdV, 1, 'first') ;

if isempty(tGoStim)
    if ~isempty(tNegStim)
        error('NoGo 試行です（負のパルスのみ）。RT の算出対象外です。') ;
    else
        error('LED のパルスが検出できませんでした。') ;
    end
end

if isempty(tNegStim)
    cueText = 'Go' ;
elseif tNegStim > tGoStim
    cueText = 'Stop' ;    % Go の後に負パルス → 停止信号あり
else
    cueText = 'NoGo' ;
end

% キューを時刻 0 にそろえる（この時点以降、両方の時間軸はキュー基準）
t       = t       - tAnalog(tGoStim) ;
tAnalog = tAnalog - tAnalog(tGoStim) ;

%% ---- 6. 床反力のフィルタと、前足接地の検出 ----
[b, a] = butter(2, Prm.ForceFc/(analogFs/2), 'low') ;
force1 = filtfilt(b, a, force1) ;
force2 = filtfilt(b, a, force2) ;

force = force1 + force2 ;
fx    = force(:,1) ;          % 前後方向の合成床反力 [N]

tFootContact = find(force2(tGoStim:nAnalog, 3) > Prm.FootContactN, 1, 'first') ;

if isempty(tFootContact)
    error('前足の接地が検出できませんでした。') ;
end
tFootContact = tFootContact + tGoStim - 1 ;

if tFootContact - tGoStim < 50
    error('キューから接地までが %d サンプルしかありません（探索窓が短すぎます）。', ...
        tFootContact - tGoStim) ;
end

%% ---- 7. RT 検出：Fx のピーク相対閾値（持続条件つき）----
%  ベースラインには中央値を使い、SD は使わない。
%  ノイズ水準が試行間・被験者間で大きく異なるため（技術説明.md §3-3）。
nDur = round(Prm.DurMs/1000 * analogFs) ;

isBase = tAnalog >= -Prm.BaseSec & tAnalog < 0 ;
baseFx = median( fx(isBase) ) ;
peakFx = max( fx(tGoStim:tFootContact) - baseFx ) ;

if peakFx <= 0
    error('探索窓内で Fx がベースラインを上回りません（要目視確認）。') ;
end

thresholdFx = baseFx + peakFx * Prm.RatioFx ;
isOver      = fx > thresholdFx ;

tOnsetFx = NaN ;                          % 見つからなければ NaN。1 にすると偽の RT が出る
for k = tGoStim+1 : (tFootContact - nDur + 1)
    if ~isOver(k-1) && all( isOver(k : k+nDur-1) )
        tOnsetFx = k ;
        break
    end
end

if isnan(tOnsetFx)
    warning('RT onset が検出できませんでした（要目視確認）。') ;
end

%% ---- 8. バット先端の速度 ----
top        = Markers.top ;
topVel     = diff3p(top, 1/fs) ;
topVelNorm = sum(topVel.^2, 2).^0.5 ;      % 合成速度 [mm/s]

% ピークはキュー以降に限定して探す。
% 試行全体から探すと、キュー前の素振りや構え直しを拾うことがある。
% analogFs/fs = 4 なので、アナログ番号をマーカー番号に直してから使う。
iGoFrame = max(1, round(tGoStim / (analogFs/fs))) ;
[peakTopVel, iRel] = max( topVelNorm(iGoFrame:end) ) ;
tPeakTopVel = iRel + iGoFrame - 1 ;

%% ---- 9. 結果 ----
Result.SubjectID     = Data.SubjectID ;
Result.ConditionName = Data.ConditionName ;
Result.TrialNumber   = Data.TrialNumber ;
Result.CueText       = cueText ;

Result.PeakTopVel = peakTopVel / 1000 ;                               % [m/s]

if isnan(tOnsetFx)
    % onset が取れなかった試行。図は描いて原因を目視できるようにし、
    % 値は NaN のままにする（0 や 1 を入れると偽の RT が結果に混ざる）。
    Result.RT             = NaN ;
    Result.MT             = NaN ;
    Result.AveSlopeTopVel = NaN ;
else
    Result.RT = (tAnalog(tOnsetFx) - tAnalog(tGoStim)) * 1000 ;   % [ms]
    Result.MT = (t(tPeakTopVel)    - tAnalog(tOnsetFx)) * 1000 ;  % [ms]

    % 平均加速度 [m/s^2]：割る前に秒へそろえる。
    % （peakTopVel[mm/s] / MT[ms] でも単位は打ち消し合って m/s^2 になるが、読み手に伝わらない）
    Result.AveSlopeTopVel = Result.PeakTopVel / (Result.MT/1000) ;
end

fprintf('\nS%02d %s trial %d [%s]\n', ...
    Result.SubjectID, Result.ConditionName, Result.TrialNumber, Result.CueText) ;
fprintf('  RT             = %6.1f ms\n',     Result.RT) ;
fprintf('  MT             = %6.1f ms\n',     Result.MT) ;
fprintf('  PeakTopVel     = %6.2f m/s\n',    Result.PeakTopVel) ;
fprintf('  AveSlopeTopVel = %6.1f m/s^2\n',  Result.AveSlopeTopVel) ;

%% ---- 10. 作図 ----
figure('Color', 'w', 'Position', [100 100 900 800]) ;

xRange = [-0.5, 1.5] ;

% --- 上段：バット先端速度 ---
ax1 = subplot(3,1,[1 2]) ;
plot(t, topVelNorm/1000, 'k-', 'LineWidth', 1.2) ; hold on
xline(0,                    'k-',  'Cue',    'LineWidth', 1.5, 'LabelOrientation', 'horizontal') ;
if ~isnan(tOnsetFx)
    xline(tAnalog(tOnsetFx), 'b--', 'Onset', 'LineWidth', 1.2, 'LabelOrientation', 'horizontal') ;
end
xline(t(tPeakTopVel),       'r--', 'Peak',   'LineWidth', 1.2, 'LabelOrientation', 'horizontal') ;
yline(Result.PeakTopVel,    'r:',  'LineWidth', 1.0) ;
xlim(xRange) ;
ylabel('Bat tip velocity [m/s]') ;
title(sprintf('S%02d %s trial %d [%s]   RT = %.0f ms,  MT = %.0f ms,  Peak = %.1f m/s,  Slope = %.1f m/s^2', ...
    Result.SubjectID, Result.ConditionName, Result.TrialNumber, Result.CueText, ...
    Result.RT, Result.MT, Result.PeakTopVel, Result.AveSlopeTopVel)) ;
grid on

% --- 下段：前後方向の床反力と RT 検出の様子 ---
ax2 = subplot(3,1,3) ;
plot(tAnalog, fx, 'k-', 'LineWidth', 1.2) ; hold on
yline(baseFx,      'k:',  'baseline',  'LineWidth', 1.0, 'LabelHorizontalAlignment', 'left') ;
yline(thresholdFx, 'b--', 'threshold', 'LineWidth', 1.0) ;
xline(0,                       'k-',  'LineWidth', 1.5) ;
xline(tAnalog(tFootContact),   'g-.', 'FootContact', 'LineWidth', 1.2, 'LabelOrientation', 'horizontal') ;
if ~isnan(tOnsetFx)
    xline(tAnalog(tOnsetFx), 'b--', 'LineWidth', 1.2) ;
    plot(tAnalog(tOnsetFx), fx(tOnsetFx), 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b') ;
else
    text(mean(xRange), double(baseFx), 'onset 未検出', 'Color', 'r', ...
        'FontSize', 12, 'HorizontalAlignment', 'center') ;
end
xlim(xRange) ;
xlabel('Time from cue [s]') ;
ylabel('F_x  [N]') ;
grid on

linkaxes([ax1 ax2], 'x') ;
