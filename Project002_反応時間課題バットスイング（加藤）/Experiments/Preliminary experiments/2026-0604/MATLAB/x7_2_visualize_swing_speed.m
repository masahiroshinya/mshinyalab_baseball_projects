% x7_2_visualize_swing_speed.m
%
% 目的:
%   バット先端速度を4つの図で可視化する。横軸はすべて Go cue からの時間。
%     figure 1 : 合成速度のピーク（散布図：ピーク時刻 × ピーク値）
%     figure 2 : 合成速度の時系列（条件ごと・全試行重ね描き／NoGo 除外）
%     figure 3 : Vx のピーク（散布図：ピーク時刻 × ピーク値）
%     figure 4 : Vx の時系列（条件ごと・全試行重ね描き／NoGo 除外）
%
% 入力:
%   x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults<ID>.mat
%       → SingleTrialResultArray（波形 NetVelTop・VelTopX を持つ）
%   x3_DataChecked/Data<ID>.mat
%       → FrameRate（時間軸を秒に直すために必要）
%
% 備考:
%   - 従来の x7_2 は x7_MultiTrialAnalysisResultsChecked/ の ResultsTable を
%     読んでいたが、あの表はスカラー列しか持たず波形がないため、
%     時系列グラフ（figure 2・4）が描けない。→ 読み込み元を x5_Checked に変更した。
%   - Vx は +X = 投手方向（s3b で両被験者 40/40 で確認済み）。正 = 投手方向。
%   - 角速度による指標は廃止済み（00 §2）。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject = 1;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
ConditionColor     = {'g', 'b', 'r'} ;
nCondition         = numel(ConditionNameArray) ;

SHOW_NOGO_IN_SCATTER = false ;    % figure 1・3 に NoGo を含めるか
XLIM_TIMESERIES      = [-0.5 2.0] ;   % 時系列グラフの表示範囲 [s]

% -----------------------------------------------------------------------
% データ読み込み
% -----------------------------------------------------------------------
load(sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject))
load(sprintf('x3_DataChecked/Data%02d', iSubject))

nTrial = size(SingleTrialResultArray, 1) ;

% -----------------------------------------------------------------------
% figure 1・3：ピークの散布図（横軸＝ピークが出た時刻）
% -----------------------------------------------------------------------
figure(1) ; clf ; hold on
figure(3) ; clf ; hold on

fprintf('=== Subject %02d：ピークの時刻と値 ===\n', iSubject) ;

% 箱ひげ図用の蓄積（条件ループをまたいで貯める）
boxVel   = [] ;    % 合成速度のピーク
boxVelX  = [] ;    % Vx のピーク
boxLabel = {} ;    % 各データ点がどの条件のものか

for iCondition = 1:nCondition

    tPeakList  = [] ;   peakList  = [] ;    % Go 用（合成速度）
    tPeakListX = [] ;   peakListX = [] ;    % Go 用（Vx）
    tNoGo      = [] ;   pNoGo     = [] ;    % NoGo 用（合成速度）
    tNoGoX     = [] ;   pNoGoX    = [] ;    % NoGo 用（Vx）

    for iTrial = 1:nTrial

        Result = SingleTrialResultArray(iTrial, iCondition) ;

        if isempty(Result.NetVelTop),  continue, end
        if isnan(Result.TCueMarker),   continue, end

        fs = DataArray(iTrial, iCondition).FrameRate ;

        % 合成速度のピーク（時刻は m3 が保存した TPeakVelTop を使う）
        tPeak = (Result.TPeakVelTop - Result.TCueMarker) / fs ;
        peak  = Result.PeakVelTop ;

        % Vx のピーク（m3 が保存した値を使う）
        peakX  = Result.PeakVelTopX ;
        tPeakX = (Result.TPeakVelTopX - Result.TCueMarker) / fs ;


        if strcmp(Result.CueText, 'Go')
            tPeakList(end+1)  = tPeak  ; peakList(end+1)  = peak  ; %#ok<SAGROW>
            tPeakListX(end+1) = tPeakX ; peakListX(end+1) = peakX ; %#ok<SAGROW>
        else
            tNoGo(end+1)  = tPeak  ; pNoGo(end+1)  = peak  ;        %#ok<SAGROW>
            tNoGoX(end+1) = tPeakX ; pNoGoX(end+1) = peakX ;        %#ok<SAGROW>
        end

    end % iTrial

    % 箱ひげ図用に貯める（Go 試行のみ）
    boxVel   = [boxVel   ; peakList(:)] ;
    boxVelX  = [boxVelX  ; peakListX(:)] ;
    boxLabel = [boxLabel ; repmat(ConditionNameArray(iCondition), numel(peakList), 1)] ;

    fprintf('%-7s Go: n=%2d, ピーク %.1f±%.1f m/s, 時刻 %.2f±%.2f s\n', ...
        ConditionNameArray{iCondition}, numel(peakList), ...
        mean(peakList), std(peakList), mean(tPeakList), std(tPeakList)) ;

    figure(1)
    scatter(tPeakList, peakList, 45, ConditionColor{iCondition}, 'filled', ...
        'DisplayName', ConditionNameArray{iCondition}) ;
    if SHOW_NOGO_IN_SCATTER && ~isempty(tNoGo)
        scatter(tNoGo, pNoGo, 45, ConditionColor{iCondition}, 'x', 'LineWidth', 1.5, ...
            'DisplayName', [ConditionNameArray{iCondition} ' (NoGo)']) ;
    end

    figure(3)
    scatter(tPeakListX, peakListX, 45, ConditionColor{iCondition}, 'filled', ...
        'DisplayName', ConditionNameArray{iCondition}) ;
    if SHOW_NOGO_IN_SCATTER && ~isempty(tNoGoX)
        scatter(tNoGoX, pNoGoX, 45, ConditionColor{iCondition}, 'x', 'LineWidth', 1.5, ...
            'DisplayName', [ConditionNameArray{iCondition} ' (NoGo)']) ;
    end

end % iCondition

figure(1)
hold off
xlabel('Go cue からの時間 (s)') ;
ylabel('合成速度のピーク (m/s)') ;
title(sprintf('Subject %02d：合成速度のピーク', iSubject)) ;
legend('Location', 'best') ; grid on

figure(3)
hold off
xlabel('Go cue からの時間 (s)') ;
ylabel('Vx のピーク (m/s)') ;
title(sprintf('Subject %02d：投手方向成分 Vx のピーク', iSubject)) ;
legend('Location', 'best') ; grid on

% -----------------------------------------------------------------------
% figure 5：条件別ピーク速度の箱ひげ図（Go 試行）
% -----------------------------------------------------------------------
figure(5) ; clf

% 2つの箱ひげ図で縦軸を揃える（Vx が合成速度の何割かを目で見るため）
yLo = min([boxVel ; boxVelX]) - 1 ;
yHi = max([boxVel ; boxVelX]) + 1 ;

subplot(1,2,1)
boxplot(boxVel, boxLabel, 'GroupOrder', ConditionNameArray) ;
set(gca, 'YLim', [yLo yHi]) ;
ylabel('合成速度のピーク (m/s)') ;
title(sprintf('Subject %02d：合成速度ピーク平均', iSubject)) ;
grid on

subplot(1,2,2)
boxplot(boxVelX, boxLabel, 'GroupOrder', ConditionNameArray) ;
set(gca, 'YLim', [yLo yHi]) ;
ylabel('Vx のピーク (m/s)') ;
title(sprintf('Subject %02d：Vxピーク平均', iSubject)) ;
grid on

% -----------------------------------------------------------------------
% figure 2・4：時系列（条件ごとに subplot、全試行を重ね描き。NoGo は除外）
% -----------------------------------------------------------------------
figure(2) ; clf
figure(4) ; clf

for iCondition = 1:nCondition

    nShown = 0 ;

    for iTrial = 1:nTrial

        Result = SingleTrialResultArray(iTrial, iCondition) ;

        if ~strcmp(Result.CueText, 'Go'), continue, end   % NoGo 除外
        if isempty(Result.NetVelTop),     continue, end
        if isnan(Result.TCueMarker),      continue, end

        fs     = DataArray(iTrial, iCondition).FrameRate ;
        tArray = ((1:numel(Result.NetVelTop))' - Result.TCueMarker) / fs ;

        nShown = nShown + 1 ;

        % 凡例は各条件の1本目にだけ付ける
        if nShown == 1
            visArg = {'DisplayName', ConditionNameArray{iCondition}} ;
        else
            visArg = {'HandleVisibility', 'off'} ;
        end

        figure(2)
        subplot(nCondition, 1, iCondition) ; hold on
        plot(tArray, Result.NetVelTop, '-', 'Color', ConditionColor{iCondition}, ...
            'LineWidth', 0.8, visArg{:}) ;

        figure(4)
        subplot(nCondition, 1, iCondition) ; hold on
        plot(tArray, Result.VelTopX, '-', 'Color', ConditionColor{iCondition}, ...
            'LineWidth', 0.8, visArg{:}) ;

    end % iTrial

    figure(2)
    subplot(nCondition, 1, iCondition) ; hold off
    set(gca, 'XLim', XLIM_TIMESERIES) ;
    xlabel('Go cue からの時間 (s)') ;
    ylabel('合成速度 (m/s)') ;
    title(sprintf('%s（Go %d 試行）', ConditionNameArray{iCondition}, nShown)) ;
    grid on

    figure(4)
    subplot(nCondition, 1, iCondition) ; hold off
    yline(0, 'k:') ;
    set(gca, 'XLim', XLIM_TIMESERIES) ;
    xlabel('Go cue からの時間 (s)') ;
    ylabel('Vx (m/s)') ;
    title(sprintf('%s（Go %d 試行）', ConditionNameArray{iCondition}, nShown)) ;
    grid on

end % iCondition

figure(2)
sgtitle(sprintf('Subject %02d：合成速度の時系列（NoGo 除外）', iSubject)) ;

figure(4)
sgtitle(sprintf('Subject %02d：投手方向成分 Vx の時系列（NoGo 除外）', iSubject)) ;
