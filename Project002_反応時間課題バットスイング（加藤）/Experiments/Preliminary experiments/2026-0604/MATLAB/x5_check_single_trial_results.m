% x5_check_single_trial_results.m
%
% 目的:
%   x4 の単一試行分析結果を目視確認し、問題がなければ
%   x5_SingleTrialAnalysisResultsChecked/ に保存する。
%
% 操作方法:
%   グラフが1試行ずつ表示される。
%   コマンドウィンドウで Enter キーを押すと次の試行へ進む。
%   全試行を確認後、保存するか確認メッセージが出る。
%
% 備考:
%   速度波形は m3 が計算済みのものを Result.NetVelTop から読む（再計算しない）。
%   角速度による検出は廃止したため、閾値線・SwingOnset 線は描かない（00 §2 の決定）。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject   = 1;
iCondition = 3;   % 1=free, 2=simple, 3=gonogo
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
condName           = ConditionNameArray{iCondition} ;   % 番号に応じて自動で設定

% -----------------------------------------------------------------------
% データ読み込み
% -----------------------------------------------------------------------
load(sprintf('x3_DataChecked/Data%02d',                            iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

nTrials = size(SingleTrialResultArray, 1) ;
fprintf('--- 目視確認開始: Subject %d, %s, 全%d試行 ---\n', iSubject, condName, nTrials) ;
fprintf('Enter キーで次の試行へ進みます。\n\n') ;

% -----------------------------------------------------------------------
% 試行ループ（1試行ずつグラフ表示）
% -----------------------------------------------------------------------
for iTrial = 1:nTrials

    Data   = DataArray(iTrial, iCondition) ;
    Result = SingleTrialResultArray(iTrial, iCondition) ;
    fs     = Data.FrameRate ;

    % m3 が計算した速度波形をそのまま使う（再計算しない）
    netVelTop = Result.NetVelTop ;

    if isempty(netVelTop)
        fprintf('  → Trial %d: 解析結果なし（エラー試行）。スキップします。\n', iTrial) ;
        continue
    end

    % グラフ描画
    nFrames = length(netVelTop) ;
    if ~isnan(Result.TCueMarker)
        tArray = ([1:nFrames] - Result.TCueMarker) / fs ;
    else
        tArray = [1:nFrames] / fs ;   % 絶対時間（秒）で表示
    end

    figure(1) ; clf

    subplot(3,1,[1 2])
    plot(tArray, netVelTop, 'b-', 'LineWidth', 1.2) ;
    set(gca, 'XLim', [-0.5, 2.5]) ;
    xlabel('LED からの時間 (s)') ;
    ylabel('バット先端速度 (m/s)') ;
    title(sprintf('Trial %d / %d  [%s]  PeakVelTop = %.1f m/s', ...
        iTrial, nTrials, Result.CueText, Result.PeakVelTop)) ;
    grid on

    subplot(3,1,3)
    nAnalog      = size(Data.LEDData, 1) ;
    if ~isnan(Result.TCueMarker)
        tCueAnalog = round(Result.TCueMarker / fs * Data.AnalogFs) ;
        tAnalog = ([1:nAnalog] - tCueAnalog) / Data.AnalogFs ;
    else
        tAnalog = [1:nAnalog] / Data.AnalogFs ;
    end
    plot(tAnalog, Data.LEDData) ;
    set(gca, 'XLim', [-0.5, 2.5]) ;
    xlabel('LED からの時間 (s)') ;
    ylabel('LED 信号 (V)') ;
    grid on

    % Enter キー待ち
    input(sprintf('  → Trial %d: CueText=%s, PeakVelTop=%.1f m/s   [Enter で次へ]', ...
        iTrial, Result.CueText, Result.PeakVelTop)) ;

end

% -----------------------------------------------------------------------
% 確認完了後に保存
% -----------------------------------------------------------------------
answer = input('\n全試行を確認しました。x5 に保存しますか？ [y/n]: ', 's') ;
if strcmpi(answer, 'y')
    savePath = sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject) ;
    save(savePath, 'SingleTrialResultArray') ;
    fprintf('保存完了: %s.mat\n', savePath) ;
else
    fprintf('保存をキャンセルしました。\n') ;
end
