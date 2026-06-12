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

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject   = 1 ;
iCondition = 3;   % 1=free, 2=simple, 3=gonogo
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
condName           = ConditionNameArray{iCondition} ;   % 番号に応じて自動で設定


THRESHOLD_OMEGA = 300 ;   % [deg/s]

% -----------------------------------------------------------------------
% データ読み込み
% -----------------------------------------------------------------------
load(sprintf('x3_DataChecked/Data%02d',                            iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

Prm = parameters ;

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

    % 角速度の再計算
    fc = Prm.Fc ;
    [b, a] = butter(2, fc/(fs/2)) ;
    fields = fieldnames(Data.Markers) ;
    for i = 1:numel(fields)
        f = fields{i} ;
        x = Data.Markers.(f) ;
        t = (1:size(x,1))' ;
        for col = 1:size(x,2)
            nanIdx = isnan(x(:,col)) ;
            if any(nanIdx) && any(~nanIdx)
                x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
            end
        end
        Data.Markers.(f) = x ;
    end

    M           = filt_all_fields(b, a, Data.Markers) ;
    v_long      = M.top - M.bottom ;
    v_long_norm = sum(v_long.^2, 2).^0.5 ;
    e_long      = v_long ./ v_long_norm ;
    de_long     = diff3p(e_long, 1/fs) ;
    omega_deg   = sum(de_long.^2, 2).^0.5 * (180/pi) ;

    % グラフ描画
    nFrames = length(omega_deg) ;
    if ~isnan(Result.TCueMarker)
        tArray = ([1:nFrames] - Result.TCueMarker) / fs ;
        xLabel = 'LED からの時間 (s)' ;
    else
        tArray = [1:nFrames] / fs ;   % 絶対時間（秒）で表示
        xLabel = '時間 (s)' ;
    end



    figure(1) ; clf

    subplot(3,1,[1 2])
    plot(tArray, omega_deg, 'b-', 'LineWidth', 1.2) ; hold on
    yline(THRESHOLD_OMEGA, 'r--', sprintf('%d deg/s', THRESHOLD_OMEGA)) ;
    if ~isnan(Result.SwingOnset)
        tSO = (Result.SwingOnset - Result.TCueMarker) / fs ;
        xline(tSO, 'r-') ;
    end
    set(gca, 'XLim', [-0.5, 2.5]) ;
    xlabel('LED からの時間 (s)') ;
    ylabel('角速度 (deg/s)') ;
    if ~isnan(Result.RT)
        title(sprintf('Trial %d / %d  [%s]  RT = %.0f ms', iTrial, nTrials, Result.CueText, Result.RT)) ;
    else
        title(sprintf('Trial %d / %d  [%s]  スイング未検出', iTrial, nTrials, Result.CueText)) ;
    end
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
    input(sprintf('  → Trial %d: CueText=%s, RT=%.0f ms   [Enter で次へ]', ...
        iTrial, Result.CueText, Result.RT)) ;

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
