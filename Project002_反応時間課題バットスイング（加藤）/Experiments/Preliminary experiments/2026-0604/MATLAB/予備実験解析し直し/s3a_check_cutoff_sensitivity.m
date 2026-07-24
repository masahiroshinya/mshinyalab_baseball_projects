% s3a_check_cutoff_sensitivity.m
%
% 目的：ローパスフィルタの遮断周波数 Fc が PeakVelTop に与える影響を調べ、
%       parameters.m の Prm.Fc = 30 に根拠を与える。（01 論点1 / ステップ1）
%
% 背景：
%   Prm.Fc = 30 は角速度時代から引き継いだ値で、
%   並進速度のピークを測る目的で検証されたことは一度もない。
%
% 判断の仕方（プラトーを探す）：
%   Fc に対して PeakVelTop をプロットすると、次の形になるはず。
%     Fc が低すぎる → 本物のピークを削ってしまう      → 過小評価（低く出る）
%     Fc がちょうどいい → 本物は全部通り、ノイズは最小 → 真の値（プラトー＝横ばい）
%     Fc が高すぎる → 本物はもう全部通っている。増えるのはノイズだけ → 水増し（じわじわ上がる）
%   微分はノイズを 2*pi*f 倍に増幅するため、Fc を上げるほどノイズが速度に化ける。
%   → プラトーの入り口が適切な Fc。現行の 30 がプラトーの中にあるかを見る。
%
% SD にも注目すること：
%   ノイズは試行ごとにランダムなので、水増しの量も試行ごとに変わる。
%   Fc が高すぎると PeakVelTop の SD が膨らみ、条件間の差がその中に埋もれる。
%   ② の目的は条件間比較なので、平均のズレより SD の膨らみのほうが実害が大きい。
%
% 注意：
%   - x3_DataChecked/ を相対パスで読むため、
%     MATLAB のカレントディレクトリを 2026-0604/MATLAB にして実行すること。
%   - 00 の教訓「1人目で成立した基準は2人目で成立するとは限らない」に従い、
%     最初から S01・S02 の両方を回す。

clear; close all; clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
subjects           = [1 2] ;
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition         = length(ConditionNameArray) ;
fcList             = [5 10 15 20 30 50] ;   % [Hz] 遮断周波数の候補
FC_CURRENT         = 30 ;                   % [Hz] 現行の Prm.Fc

nFc = length(fcList) ;

for iSubject = subjects

    fprintf('\n========================================\n') ;
    fprintf('  Subject %02d\n', iSubject) ;
    fprintf('========================================\n') ;

    load(sprintf('x3_DataChecked/Data%02d', iSubject))
    load(sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject))

    nTrial = size(DataArray, 1) ;

    meanPeak = nan(nCondition, nFc) ;
    sdPeak   = nan(nCondition, nFc) ;

    for iCondition = 1:nCondition

        peakAll = nan(nTrial, nFc) ;

        for iTrial = 1:nTrial

            Data   = DataArray(iTrial, iCondition) ;
            Result = SingleTrialResultArray(iTrial, iCondition) ;

            % Go 試行のみ（NoGo はスイングしないので比較対象にならない）
            if ~strcmp(Result.CueText, 'Go'), continue, end

            fs = Data.FrameRate ;

            % ---- NaN 補間（m3 と同じ。top マーカーだけでよい）----
            %  filtfilt はフィールドごとに独立にかかるので、
            %  top だけ処理しても m3 と同じ結果になる。
            x = Data.Markers.top ;
            t = (1:size(x,1))' ;
            for col = 1:size(x,2)
                nanIdx = isnan(x(:,col)) ;
                if any(nanIdx) && any(~nanIdx)
                    x(nanIdx,col) = interp1(t(~nanIdx), x(~nanIdx,col), t(nanIdx), 'linear', 'extrap') ;
                end
            end
            posTopRaw = x / 1000 ;    % [m] mm → m（m3 と同じく微分の前に直す）

            % ---- Fc を振って PeakVelTop を計算 ----
            for iFc = 1:nFc
                fc = fcList(iFc) ;
                if fc >= fs/2       % Nyquist を超える Fc は設計できない
                    continue
                end
                [b, a]    = butter(2, fc/(fs/2)) ;
                posTop    = filtfilt(b, a, posTopRaw) ;
                velTop    = diff3p(posTop, 1/fs) ;
                netVelTop = sum(velTop.^2, 2).^0.5 ;
                peakAll(iTrial, iFc) = max(netVelTop) ;
            end

        end % iTrial

        meanPeak(iCondition, :) = mean(peakAll, 1, 'omitnan') ;
        sdPeak(iCondition, :)   = std(peakAll, 0, 1, 'omitnan') ;

        % ---- 表示 ----
        nValid = sum(~isnan(peakAll(:,1))) ;
        fprintf('\n--- %s （Go 試行 n=%d）---\n', ConditionNameArray{iCondition}, nValid) ;
        fprintf('Fc      [Hz] :') ; fprintf('%9.0f', fcList) ; fprintf('\n') ;
        fprintf('平均Peak[m/s]:') ; fprintf('%9.2f', meanPeak(iCondition,:)) ; fprintf('\n') ;
        fprintf('SD      [m/s]:') ; fprintf('%9.3f', sdPeak(iCondition,:)) ; fprintf('\n') ;

        % 前の Fc からの増分。プラトーではこれがほぼ 0 になる。
        dPeak = [NaN, diff(meanPeak(iCondition,:))] ;
        fprintf('前Fcとの差   :') ; fprintf('%9.3f', dPeak) ; fprintf('\n') ;

        % 現行 Fc=30 との差。30 が水増ししているなら、低い Fc で負になる。
        idx30 = find(fcList == FC_CURRENT, 1) ;
        if ~isempty(idx30)
            fprintf('Fc=30との差  :') ; fprintf('%9.3f', meanPeak(iCondition,:) - meanPeak(iCondition,idx30)) ; fprintf('\n') ;
        end

    end % iCondition

    % -------------------------------------------------------------------
    % グラフ：Fc に対する PeakVelTop（プラトーを目で探す）
    % -------------------------------------------------------------------
    figure(iSubject) ; clf

    subplot(2,1,1)
    hold on
    for iCondition = 1:nCondition
        errorbar(fcList, meanPeak(iCondition,:), sdPeak(iCondition,:), ...
            '-o', 'LineWidth', 1.2, 'DisplayName', ConditionNameArray{iCondition}) ;
    end
    xline(FC_CURRENT, 'r--', sprintf('現行 Fc = %d Hz', FC_CURRENT)) ;
    hold off
    xlabel('遮断周波数 Fc (Hz)') ;
    ylabel('平均 PeakVelTop (m/s)') ;
    title(sprintf('Subject %02d：遮断周波数に対する PeakVelTop（平均±SD）', iSubject)) ;
    legend('Location', 'best') ;
    grid on

    % SD 単独。Fc を上げると膨らむかを見る（条件差が埋もれるかの指標）
    subplot(2,1,2)
    hold on
    for iCondition = 1:nCondition
        plot(fcList, sdPeak(iCondition,:), '-o', 'LineWidth', 1.2, ...
            'DisplayName', ConditionNameArray{iCondition}) ;
    end
    xline(FC_CURRENT, 'r--') ;
    hold off
    xlabel('遮断周波数 Fc (Hz)') ;
    ylabel('PeakVelTop の SD (m/s)') ;
    title('ばらつき（SD）が Fc とともに膨らむか') ;
    legend('Location', 'best') ;
    grid on

    clear DataArray SingleTrialResultArray

end % iSubject

fprintf('\n=== 完了 ===\n') ;
fprintf('見方：平均Peak が横ばいになった区間がプラトー。その入り口が適切な Fc。\n') ;
fprintf('      Fc=30 がプラトー内なら現行のままでよい（根拠がついたことになる）。\n') ;
fprintf('      Fc=30 でまだ上がり続けているなら、それはノイズの水増し。\n') ;
