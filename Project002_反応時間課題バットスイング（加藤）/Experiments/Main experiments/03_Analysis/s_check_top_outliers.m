% s_check_top_outliers.m
%
% 目的:
%   PeakVelTop の外れ値の正体を切り分け、除外候補を洗い出す。
%   x3_DataChecked/ の座標と x5_SingleTrialAnalysisResultsChecked/ の解析結果を読み、
%   試行ごとに品質指標を並べて表示する。
%
% 入力:
%   x3_DataChecked/Data<ID>.mat                            → DataArray
%   x5_SingleTrialAnalysisResultsChecked/...<ID>.mat       → SingleTrialResultArray
%
% 出力（コマンドウィンドウ）:
%   表1  PeakVelTop の降順 30 試行
%   表2  被験者ごとの分布
%   表3  品質フラグの内訳
%   表4  除外候補の一覧
%
% 指標の意味:
%   PeakVelTop   バット先端の合成速度のピーク [m/s]
%   tPeak_s      ピークの時刻（Go cue 基準 [s]）。スイングなら 0.2〜1.5 s 付近
%   EdgePeak     ピークが試行の先頭/末尾 5 フレーム以内か（微分の端の跳ね）
%   StepMax_mm   top のフレーム間変位の最大値 [mm]。マーカーの飛びの指標
%   JumpRatio    StepMax を速度換算して PeakVelTop で割った値。
%                座標が滑らかなら 1 前後。不連続があると 1 を大きく上回る
%   nNanTop      補間しきれず NaN が残った top のフレーム数（試行全体）
%   nNanInWin    そのうち解析窓（cue 後 0〜2 秒）に入っているフレーム数
%
% 備考:
%   計測は 250 Hz。バット先端の実測ピークは 27〜35 m/s なので、
%   1 フレームあたりの変位は 110〜140 mm 程度になる。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
subjects           = 1:5 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;

EDGE_MARGIN  = 5 ;     % 「試行の端」とみなすフレーム数
STEP_MAX_MM  = 200 ;   % これを超えるフレーム間変位は計測不良とみなす
                       % （200 mm/frame ＝ 50 m/s 相当。スイングでは起こりえない）
N_SHOW       = 30 ;    % 表1 に表示する試行数

Prm    = parameters ;
winSec = Prm.RT.WinSec ;   % 解析窓の長さ [s]。m3 のピーク探索と揃える

T = table() ;

% -----------------------------------------------------------------------
% 被験者ループ
% -----------------------------------------------------------------------
for iSubject = subjects

    dataPath   = sprintf('x3_DataChecked/Data%02d', iSubject) ;
    resultPath = sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject) ;

    if ~exist([dataPath '.mat'], 'file') || ~exist([resultPath '.mat'], 'file')
        fprintf('S%02d: 中間ファイルが見つかりません。スキップします。\n', iSubject) ;
        continue
    end

    load(dataPath)      % → DataArray
    load(resultPath)    % → SingleTrialResultArray

    nTrial     = size(SingleTrialResultArray, 1) ;
    nCondition = min(size(SingleTrialResultArray, 2), numel(ConditionNameArray)) ;

    for iCondition = 1:nCondition
        for iTrial = 1:nTrial

            R = SingleTrialResultArray(iTrial, iCondition) ;
            D = DataArray(iTrial, iCondition) ;

            % 解析結果が空の要素（欠測試行・エラー試行）は対象外
            if isempty(R.NetVelTop)
                continue
            end

            fs      = D.FrameRate ;
            posTop  = D.Markers.top ;
            nFrame  = size(posTop, 1) ;

            % ---- ピークの時刻（cue 基準）----
            if isnan(R.TCueMarker)
                tPeak = NaN ;
            else
                tPeak = (R.TPeakVelTop - R.TCueMarker) / fs ;
            end

            % ---- ピークが試行の端で起きていないか ----
            nVel       = numel(R.NetVelTop) ;
            isEdgePeak = (R.TPeakVelTop <= EDGE_MARGIN) ...
                      || (R.TPeakVelTop >= nVel - EDGE_MARGIN + 1) ;

            % ---- top のフレーム間変位（飛び・ラベル入れ替わりの検出）----
            %  NaN をまたぐ差分は NaN になるので、集計から外す。
            stepAll = sqrt(sum(diff(posTop).^2, 2)) ;
            stepAll = stepAll(~isnan(stepAll)) ;
            if isempty(stepAll)
                stepMax = NaN ;
            else
                stepMax = max(stepAll) ;
            end

            % ---- 飛びを速度換算して PeakVelTop と比べる ----
            %  座標が滑らかなら、中心差分のピークとフレーム間変位はほぼ一致する。
            %  不連続があると左辺だけが跳ね上がるので、比が 1 から離れる。
            if R.PeakVelTop > 0
                jumpRatio = (stepMax * fs / 1000) / R.PeakVelTop ;
            else
                jumpRatio = NaN ;
            end

            % ---- top の欠損（全体／解析窓内）----
            isNanFrame = any(isnan(posTop), 2) ;
            nNanTop    = sum(isNanFrame) ;

            if isnan(R.TCueMarker)
                nNanInWin = NaN ;
            else
                w         = R.TCueMarker : min(R.TCueMarker + round(winSec*fs), nFrame) ;
                nNanInWin = sum(isNanFrame(w)) ;
            end

            % ---- 品質フラグ ----
            isBadTop = (stepMax > STEP_MAX_MM) ;

            T = [T ; table(iSubject, string(ConditionNameArray{iCondition}), iTrial, ...
                string(R.CueText), R.PeakVelTop, tPeak, isEdgePeak, ...
                stepMax, jumpRatio, nNanTop, nNanInWin, isBadTop, ...
                'VariableNames', {'Subject', 'Condition', 'Trial', 'CueText', ...
                'PeakVelTop', 'tPeak_s', 'EdgePeak', ...
                'StepMax_mm', 'JumpRatio', 'nNanTop', 'nNanInWin', 'IsBadTop'})] ; %#ok<AGROW>

        end % iTrial
    end % iCondition
end % iSubject

if isempty(T)
    error('s_check_top_outliers:EmptyTable', ...
        'テーブルが空です。x5 まで実行済みか確認してください。') ;
end

T = sortrows(T, 'PeakVelTop', 'descend') ;

% -----------------------------------------------------------------------
% 表1：PeakVelTop の大きい順
% -----------------------------------------------------------------------
fprintf('=== 表1: PeakVelTop の大きい順 %d 試行 ===\n', N_SHOW) ;
disp(T(1:min(N_SHOW, height(T)), :))

% -----------------------------------------------------------------------
% 表2：被験者ごとの分布
% -----------------------------------------------------------------------
fprintf('\n=== 表2: 被験者ごとの PeakVelTop の分布 ===\n') ;
fprintf('       n    中央値     MAD      最小      最大   端ピーク\n') ;
for iSubject = subjects
    mask = (T.Subject == iSubject) ;
    if ~any(mask), continue, end
    v = T.PeakVelTop(mask) ;
    fprintf('S%02d  %3d   %6.1f   %5.1f   %6.1f   %6.1f      %2d\n', ...
        iSubject, numel(v), median(v), median(abs(v - median(v))), ...
        min(v), max(v), sum(T.EdgePeak(mask))) ;
end

% -----------------------------------------------------------------------
% 表3：品質フラグの内訳
% -----------------------------------------------------------------------
fprintf('\n=== 表3: 品質フラグの内訳（閾値 %d mm/frame）===\n', STEP_MAX_MM) ;
fprintf('       全試行   ジャンプ   窓内に欠損   どちらか\n') ;
for iSubject = subjects
    mask = (T.Subject == iSubject) ;
    if ~any(mask), continue, end
    isJump = T.IsBadTop(mask) ;
    isGap  = (T.nNanInWin(mask) > 0) ;
    fprintf('S%02d      %3d       %3d          %3d        %3d\n', ...
        iSubject, sum(mask), sum(isJump), sum(isGap), sum(isJump | isGap)) ;
end

isJumpAll = T.IsBadTop ;
isGapAll  = (T.nNanInWin > 0) ;
fprintf('計       %3d       %3d          %3d        %3d\n', ...
    height(T), sum(isJumpAll), sum(isGapAll), sum(isJumpAll | isGapAll)) ;

% -----------------------------------------------------------------------
% 表4：除外候補の一覧（ジャンプ検出）
% -----------------------------------------------------------------------
fprintf('\n=== 表4: ジャンプが検出された試行 ===\n') ;
if any(isJumpAll)
    Bad = sortrows(T(isJumpAll, :), {'Subject', 'Condition', 'Trial'}) ;
    disp(Bad(:, {'Subject', 'Condition', 'Trial', 'CueText', ...
                 'PeakVelTop', 'StepMax_mm', 'JumpRatio', 'nNanInWin'}))
else
    fprintf('  なし\n') ;
end
