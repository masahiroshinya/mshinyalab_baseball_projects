% s2a_check_velocity_waveform.m
%
% 目的：netVelTop の波形を目視し、スイング開始検出の閾値を決める材料を得る。
%       ステップ2用の検討スクリプト（パイプライン本体ではない）。

clear
close all
clc

iSubject   = 2 ;
iCondition = 2 ;   % 1=free, 2=simple, 3=gonogo
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
condName = ConditionNameArray{iCondition} ;

load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

nTrial = size(SingleTrialResultArray, 1) ;

for iTrial = 1:nTrial

    Data   = DataArray(iTrial, iCondition) ;
    Result = SingleTrialResultArray(iTrial, iCondition) ;
    fs     = Data.FrameRate ;

    netVelTop = Result.NetVelTop ;
    if isempty(netVelTop), continue, end

    % 時間軸をキュー基準（キュー = 0 s）にする。試行間で横軸が揃い、比較しやすい。
    tArray = ((1:length(netVelTop))' - Result.TCueMarker) / fs ;

    figure(1) ; clf
    plot(tArray, netVelTop, 'k-') ;
    hold on
    xline(0, 'g-', 'LineWidth', 2, 'DisplayName', 'Cue') ;          % LED点灯
    if ~isnan(Result.SwingOnset)
        xline((Result.SwingOnset - Result.TCueMarker)/fs, 'r--', ...
            'LineWidth', 1.5, 'DisplayName', '角速度による検出') ;
    end
    hold off

    xlabel('キューからの時間 [s]') ;
    ylabel('バット先端の速さ [m/s]') ;
    title(sprintf('S%02d %s Trial %d  [%s]  Peak = %.1f m/s, RT(角速度) = %.0f ms', ...
        iSubject, condName, iTrial, Result.CueText, Result.PeakVelTop, Result.RT)) ;
    grid on
    legend('Location', 'northwest') ;

    % ---- 立ち上がりの根元を見るための拡大図 ----
    figure(2) ; clf
    plot(tArray, netVelTop, 'k-') ;
    hold on
    xline(0, 'g-', 'LineWidth', 2) ;
    if ~isnan(Result.SwingOnset)
        xline((Result.SwingOnset - Result.TCueMarker)/fs, 'r--', 'LineWidth', 1.5) ;
    end
    hold off
    xlim([-0.5 2.0]) ;      % キュー前0.5秒 〜 キュー後2秒
    ylim([0 3]) ;           % 低速側だけを拡大（ピークは切れて良い）
    xlabel('キューからの時間 [s]') ;
    ylabel('バット先端の速さ [m/s]') ;
    title('立ち上がりの根元（拡大）') ;
    grid on

    % ---- ベースラインの数値化 ----
    baseRange = max(1, Result.TCueMarker-round(0.5*fs)) : Result.TCueMarker-1 ;
    fprintf('Trial %2d: ベースライン（キュー前0.5s） 平均 %.3f, SD %.3f, 最大 %.3f m/s\n', ...
        iTrial, mean(netVelTop(baseRange)), std(netVelTop(baseRange)), max(netVelTop(baseRange))) ;

    pause
end
