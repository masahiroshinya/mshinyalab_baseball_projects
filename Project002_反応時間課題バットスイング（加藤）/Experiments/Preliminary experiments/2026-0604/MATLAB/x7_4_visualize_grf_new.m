clear
close all
clc

iSubject = 1 ;                                    % 検証する被験者（1 or 2）

% ---- データ読み込み ----
load(sprintf('x2_Data/Data%02d', iSubject))                                          % DataArray
load(sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject))  % SingleTrialResultArray

% ---- 予備実験は3条件 ----
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;
nTrial     = size(DataArray, 1) ;                 % = 20

% ---- マーカーフィルタ用パラメータ（m3と同じ）----
Prm = parameters ;
fc  = Prm.Fc ;                                    % = 30 Hz

% ---- 結果を貯める（行=試行, 列=条件）----
PeakFyBack2 = nan(nTrial, nCondition) ;   % 踏み込み足の後方GRF [BW]
PeakFres2   = nan(nTrial, nCondition) ;   % 踏み込み足の合成GRF [BW]
ImpulseFz2  = nan(nTrial, nCondition) ;   % 踏み込み足Fzの力積 [BW·s]
PeakRFD2    = nan(nTrial, nCondition) ;   % 踏み込み足FzのRFD [BW/s]
TWeightXfer = nan(nTrial, nCondition) ;   % 体重移動タイミング [ms]
CoPpath2    = nan(nTrial, nCondition) ;   % 踏み込み足CoP総軌跡長

for iCondition = 1:nCondition
    for iTrial = 1:nTrial

        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;

        % ---- ガード（x7_3 STEP3と同じ）----
        if ~isfield(Data, 'Force1') || isempty(Data.Force1), continue, end
        if isnan(Result.TCueMarker), continue, end

        fsAnalog   = Data.AnalogFs ;
        tCueAnalog = round(Result.TCueMarker / Data.FrameRate * fsAnalog) ;
        if tCueAnalog < 2, continue, end

        Fz1 = Data.Force1(:, 3) ;   Fz2 = Data.Force2(:, 3) ;
        Fy2 = Data.Force2(:, 2) ;

        % ---- NaNガード（フォースプレートデータの欠損試行を除外）----
        if any(isnan(Fz1)) || any(isnan(Fz2)) || any(isnan(Fy2))
            continue
        end

        bw = mean(Fz1(1:tCueAnalog-1)) + mean(Fz2(1:tCueAnalog-1)) ;   % [N]
        if bw <= 0, continue, end

        swingEnd   = min(tCueAnalog + round(2*fsAnalog), length(Fz1)) ;
        swingRange = tCueAnalog : swingEnd ;

        % ===== 9.1 後方GRF・合成GRF =====
        PeakFyBack2(iTrial, iCondition) = max(-Fy2(swingRange)) / bw ;
        Fres2 = sqrt(sum(Data.Force2.^2, 2)) ;
        PeakFres2(iTrial, iCondition)   = max(Fres2(swingRange)) / bw ;

        % ===== 9.2 力積・RFD（微分前にローパス）=====
        [bF, aF] = butter(2, 50/(fsAnalog/2)) ;
        Fz2_filt = filtfilt(bF, aF, Fz2) ;
        Fz2_static = mean(Fz2(1:tCueAnalog-1)) ;
        dFz2 = Fz2_filt(swingRange) - Fz2_static ;
        ImpulseFz2(iTrial, iCondition) = trapz(dFz2) / fsAnalog / bw ;
        dFz2dt = diff3p(Fz2_filt, 1/fsAnalog) ;
        PeakRFD2(iTrial, iCondition)   = max(dFz2dt(swingRange)) / bw ;

        % ===== 9.3 体重移動タイミング（50msデバウンス付き交差検出）=====
        minHold = round(0.05 * fsAnalog) ;
        isFront = Fz2(swingRange) > Fz1(swingRange) ;
        tCross  = NaN ;
        idx     = find(isFront, 1, 'first') ;
        while ~isempty(idx)
            holdEnd = min(idx + minHold - 1, length(isFront)) ;
            if all(isFront(idx:holdEnd))
                tCross = idx ; break
            end
            nextIdx = find(isFront(holdEnd+1:end), 1, 'first') ;
            if isempty(nextIdx), break, end
            idx = holdEnd + nextIdx ;
        end
        if ~isnan(tCross)
            TWeightXfer(iTrial, iCondition) = (swingRange(tCross) - tCueAnalog) / fsAnalog * 1000 ;
        end

        % ===== 9.7 CoP軌跡（踏み込み足=プレート2）=====
        Mx2 = Data.Moment2(:, 1) ;   My2 = Data.Moment2(:, 2) ;
        valid = Fz2 > 0.05 * bw ;
        copX = nan(size(Fz2)) ;   copY = nan(size(Fz2)) ;
        copX(valid) = -My2(valid) ./ Fz2(valid) ;
        copY(valid) =  Mx2(valid) ./ Fz2(valid) ;
        copXw = copX(swingRange) ;   copYw = copY(swingRange) ;
        CoPpath2(iTrial, iCondition) = sum(sqrt(diff(copXw).^2 + diff(copYw).^2), 'omitnan') ;

    end
end

% ---- 条件別平均を表示して妥当性を確認 ----
fprintf('\n=== Subject %02d フォースプレート系指標（条件別平均）===\n', iSubject) ;
fprintf('%-10s %8s %8s %8s %8s %10s\n', '条件', 'FyBack', 'Fres', 'Impulse', 'RFD', 'WtXfer[ms]') ;
for iCondition = 1:nCondition
    fprintf('%-10s %8.3f %8.3f %8.4f %8.1f %10.1f\n', ...
        ConditionNameArray{iCondition}, ...
        mean(PeakFyBack2(:,iCondition), 'omitnan'), ...
        mean(PeakFres2(:,iCondition),   'omitnan'), ...
        mean(ImpulseFz2(:,iCondition),  'omitnan'), ...
        mean(PeakRFD2(:,iCondition),    'omitnan'), ...
        mean(TWeightXfer(:,iCondition), 'omitnan')) ;
end

figure('Name', 'STEP A: フォースプレート系指標') ; clf
subplot(2,3,1) ; boxplot_by_condition(PeakFyBack2, ConditionNameArray, 'Peak backward GRF [BW]') ; title('後方GRF（9.1）')
subplot(2,3,2) ; boxplot_by_condition(PeakFres2,   ConditionNameArray, 'Peak resultant GRF [BW]') ; title('合成GRF（9.1）')
subplot(2,3,3) ; boxplot_by_condition(ImpulseFz2,  ConditionNameArray, 'Impulse Fz [BW\cdots]') ; title('力積（9.2）')
subplot(2,3,4) ; boxplot_by_condition(PeakRFD2,    ConditionNameArray, 'Peak RFD [BW/s]') ; title('RFD（9.2）')
subplot(2,3,5) ; boxplot_by_condition(TWeightXfer, ConditionNameArray, 'Weight transfer [ms]') ; title('体重移動タイミング（9.3）')
sgtitle(sprintf('Subject %02d：フォースプレート系指標の条件比較', iSubject)) ;

iCond_show  = 3 ;   % 見たい条件（1=free,2=simple,3=gonogo）
iTrial_show = 1 ;   % 見たい試行

Data   = DataArray(iTrial_show, iCond_show) ;
Result = SingleTrialResultArray(iTrial_show, iCond_show) ;

fsA  = Data.AnalogFs ;
tCue = round(Result.TCueMarker / Data.FrameRate * fsA) ;
Fz1  = Data.Force1(:,3) ;  Fz2 = Data.Force2(:,3) ;  Fy2 = Data.Force2(:,2) ;
bw   = mean(Fz1(1:tCue-1)) + mean(Fz2(1:tCue-1)) ;
Fres2 = sqrt(sum(Data.Force2.^2, 2)) ;
tA   = ((1:length(Fz1))' - tCue) / fsA ;                 % LED基準の時間軸[s]（列ベクトル）
swingEnd = min(tCue + round(2*fsA), length(Fz1)) ; swingRange = tCue:swingEnd ;

figure('Name', 'STEP A: 代表波形') ; clf

% 上段：体重移動（Fz1/Fz2 と交差線）
subplot(3,1,1)
plot(tA, Fz1/bw, 'b-', 'DisplayName', 'プレート1（軸足）') ; hold on
plot(tA, Fz2/bw, 'r-', 'DisplayName', 'プレート2（踏み込み足）') ;
xline(0, 'k--', 'LED') ;
if ~isnan(TWeightXfer(iTrial_show, iCond_show))
    xline(TWeightXfer(iTrial_show, iCond_show)/1000, 'm-', '体重移動') ;
end
xlim([-1 2]) ; ylabel('Fz [BW]') ; legend('Location','best') ; grid on
title('体重移動タイミング（9.3）：Fz1とFz2の交差')

% 中段：力積の面積とRFDの勾配
subplot(3,1,2)
[bF,aF] = butter(2, 50/(fsA/2)) ; Fz2f = filtfilt(bF, aF, Fz2) ;
dFz2 = Fz2f - mean(Fz2(1:tCue-1)) ;                       % 静止分を引いた増加分
area(tA(swingRange), dFz2(swingRange)/bw, 'FaceAlpha', 0.3) ; hold on
plot(tA, dFz2/bw, 'r-') ; xline(0, 'k--') ;
xlim([-1 2]) ; ylabel('\DeltaFz [BW]') ; grid on
title('力積＝塗り面積 / RFD＝立ち上がりの勾配（9.2）')

% 下段：後方GRF・合成GRF
subplot(3,1,3)
plot(tA, -Fy2/bw, 'g-', 'DisplayName', '後方GRF（-Fy）') ; hold on
plot(tA, Fres2/bw, 'k-', 'DisplayName', '合成GRF') ;
xline(0, 'k--') ; xlim([-1 2]) ; ylabel('[BW]') ; xlabel('LEDからの時間 [s]') ;
legend('Location','best') ; grid on
title('後方GRF・合成GRF（9.1）')

sgtitle(sprintf('Subject %02d  %s  Trial %d：代表波形', ...
    iSubject, ConditionNameArray{iCond_show}, iTrial_show)) ;

Mx2 = Data.Moment2(:,1) ;  My2 = Data.Moment2(:,2) ;
valid = Fz2 > 0.05*bw ;
copX = nan(size(Fz2)) ;  copY = nan(size(Fz2)) ;
copX(valid) = -My2(valid) ./ Fz2(valid) ;
copY(valid) =  Mx2(valid) ./ Fz2(valid) ;

figure('Name', 'STEP A: CoP軌跡') ; clf
plot(copX(swingRange), copY(swingRange), '-', 'Color', [0.6 0.6 0.6]) ; hold on
scatter(copX(swingRange), copY(swingRange), 18, tA(swingRange), 'filled') ;
cb = colorbar ; cb.Label.String = 'LEDからの時間 [s]' ;
axis equal ; grid on ; xlabel('CoP X') ; ylabel('CoP Y') ;
title(sprintf('Subject %02d  %s  Trial %d：CoP軌跡（9.7、色=時間経過）', ...
    iSubject, ConditionNameArray{iCond_show}, iTrial_show)) ;


% ---- 各試行の波形をLED基準の共通時間軸に補間してから重ね描きする ----
% 試行ごとに録画長がわずかに違う可能性があるため、共通の時間軸(tWin)へ
% interp1で補間して揃える（範囲外はNaNにする＝伸ばして水増ししない）。

fsA_ref = DataArray(1,1).AnalogFs ;                 % 代表的なfsAnalog（全試行共通の想定。要確認）
tWin    = -1 : 1/fsA_ref : 2 ;                       % 共通の相対時間軸 [s]（LED基準）
nWin    = length(tWin) ;

% =============================================================
% (A-4) 条件別波形（薄=全試行, 濃=平均）
% =============================================================
figure('Name', 'STEP A: 条件別波形（薄=全試行, 濃=平均）') ; clf

for iCondition = 1:nCondition

    WaveFz1    = nan(nTrial, nWin) ;   % 軸足Fz
    WaveFz2    = nan(nTrial, nWin) ;   % 踏み込み足Fz
    WavedFz    = nan(nTrial, nWin) ;   % 力積の元波形（静止分を引いた増加分、フィルタ後）
    WaveFyBack = nan(nTrial, nWin) ;   % 後方GRF
    WaveFres   = nan(nTrial, nWin) ;   % 合成GRF

    for iTrial = 1:nTrial
        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;

        if ~isfield(Data, 'Force1') || isempty(Data.Force1), continue, end
        if isnan(Result.TCueMarker), continue, end

        fsA  = Data.AnalogFs ;
        tCue = round(Result.TCueMarker / Data.FrameRate * fsA) ;
        if tCue < 2, continue, end

        Fz1 = Data.Force1(:, 3) ;   Fz2 = Data.Force2(:, 3) ;   Fy2 = Data.Force2(:, 2) ;
        if any(isnan(Fz1)) || any(isnan(Fz2)) || any(isnan(Fy2)), continue, end   % NaN試行は除外

        bw = mean(Fz1(1:tCue-1)) + mean(Fz2(1:tCue-1)) ;
        if bw <= 0, continue, end

        tTrial = ((1:length(Fz1))' - tCue) / fsA ;             % その試行のLED基準時間軸

        % ---- 体重移動（Fz1・Fz2）----
        WaveFz1(iTrial,:) = interp1(tTrial, Fz1/bw, tWin, 'linear', NaN) ;
        WaveFz2(iTrial,:) = interp1(tTrial, Fz2/bw, tWin, 'linear', NaN) ;

        % ---- 力積の元波形（フィルタ後、静止分を引く）----
        [bF, aF] = butter(2, 50/(fsA/2)) ;
        Fz2_filt = filtfilt(bF, aF, Fz2) ;
        dFz2 = (Fz2_filt - mean(Fz2(1:tCue-1))) / bw ;
        WavedFz(iTrial,:) = interp1(tTrial, dFz2, tWin, 'linear', NaN) ;

        % ---- 後方GRF・合成GRF ----
        Fres2 = sqrt(sum(Data.Force2.^2, 2)) ;
        WaveFyBack(iTrial,:) = interp1(tTrial, -Fy2/bw,  tWin, 'linear', NaN) ;
        WaveFres(iTrial,:)   = interp1(tTrial, Fres2/bw, tWin, 'linear', NaN) ;
    end

    nValid = sum(any(~isnan(WaveFz2), 2)) ;

    % --- 上段：体重移動 ---
    subplot(3, nCondition, iCondition)
    plot_trials_with_mean(tWin, WaveFz1, [0.2 0.4 0.9]) ;    % 軸足（青系）
    plot_trials_with_mean(tWin, WaveFz2, [0.9 0.3 0.2]) ;    % 踏み込み足（赤系）
    xline(0, 'k--') ; xlim([-1 2]) ; ylim([-0.2 2]) ; grid on
    ylabel('Fz [BW]') ; title(sprintf('%s（n=%d）体重移動', ConditionNameArray{iCondition}, nValid)) ;
    if iCondition == 1
        h1 = plot(nan,nan,'Color',[0.2 0.4 0.9],'LineWidth',2.5) ;
        h2 = plot(nan,nan,'Color',[0.9 0.3 0.2],'LineWidth',2.5) ;
        legend([h1 h2], {'軸足(平均)','踏み込み足(平均)'}, 'Location','best') ;
    end

    % --- 中段：力積の元波形 ---
    subplot(3, nCondition, nCondition + iCondition)
    plot_trials_with_mean(tWin, WavedFz, [0.6 0.2 0.6]) ;    % 紫系
    xline(0, 'k--') ; xlim([-1 2]) ; grid on
    ylabel('\DeltaFz [BW]') ; title('力積の元波形（9.2）')

    % --- 下段：後方GRF・合成GRF ---
    subplot(3, nCondition, 2*nCondition + iCondition)
    plot_trials_with_mean(tWin, WaveFyBack, [0.2 0.7 0.3]) ; % 緑系
    plot_trials_with_mean(tWin, WaveFres,   [0.1 0.1 0.1]) ; % 黒系
    xline(0, 'k--') ; xlim([-1 2]) ; grid on
    xlabel('LEDからの時間 [s]') ; ylabel('[BW]') ; title('後方/合成GRF（9.1）')
    if iCondition == 1
        h3 = plot(nan,nan,'Color',[0.2 0.7 0.3],'LineWidth',2.5) ;
        h4 = plot(nan,nan,'Color',[0.1 0.1 0.1],'LineWidth',2.5) ;
        legend([h3 h4], {'後方GRF(平均)','合成GRF(平均)'}, 'Location','best') ;
    end

end

sgtitle(sprintf('Subject %02d：条件別波形（薄=全試行, 濃=平均）', iSubject)) ;

% =============================================================
% (A-5) 条件別CoP軌跡（薄=全試行, 濃=平均、条件ごとに別Figure）
% =============================================================
for iCondition = 1:nCondition

    CoPXMat = nan(nTrial, nWin) ;   % CoP X
    CoPYMat = nan(nTrial, nWin) ;   % CoP Y

    for iTrial = 1:nTrial
        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;

        if ~isfield(Data, 'Force1') || isempty(Data.Force1), continue, end
        if isnan(Result.TCueMarker), continue, end

        fsA  = Data.AnalogFs ;
        tCue = round(Result.TCueMarker / Data.FrameRate * fsA) ;
        if tCue < 2, continue, end

        Fz1 = Data.Force1(:, 3) ;   Fz2 = Data.Force2(:, 3) ;
        if any(isnan(Fz1)) || any(isnan(Fz2)), continue, end   % NaN試行は除外

        bw = mean(Fz1(1:tCue-1)) + mean(Fz2(1:tCue-1)) ;
        if bw <= 0, continue, end

        tTrial = ((1:length(Fz1))' - tCue) / fsA ;             % その試行のLED基準時間軸

        % ---- CoP（踏み込み足）----
        Mx2 = Data.Moment2(:,1) ;  My2 = Data.Moment2(:,2) ;
        validCoP = Fz2 > 0.05*bw ;
        copX = nan(size(Fz2)) ;  copY = nan(size(Fz2)) ;
        copX(validCoP) = -My2(validCoP) ./ Fz2(validCoP) ;
        copY(validCoP) =  Mx2(validCoP) ./ Fz2(validCoP) ;

        CoPXMat(iTrial,:) = interp1(tTrial, copX, tWin, 'linear', NaN) ;
        CoPYMat(iTrial,:) = interp1(tTrial, copY, tWin, 'linear', NaN) ;
    end

    nValid = sum(any(~isnan(CoPXMat), 2)) ;

    % ---- 条件ごとに別のFigureウィンドウを開く ----
    figure('Name', sprintf('CoP軌跡: %s', ConditionNameArray{iCondition})) ; clf
    plot_trials_with_mean_xy(CoPXMat, CoPYMat, [0.165 0.471 0.839]) ;   % 青
    axis equal ; grid on
    xlabel('CoP X') ; ylabel('CoP Y')
    title(sprintf('Subject %02d：%s（n=%d）CoP軌跡（薄=全試行, 濃=平均）', ...
        iSubject, ConditionNameArray{iCondition}, nValid)) ;

end
