% x7_3_visualize_grf.m
%
% 目的:
%   床反力（GRF: Ground Reaction Force）を可視化し、条件間で比較する。
%     figure 1   : 条件別ピーク Fz の箱ひげ図（後ろ足／踏み込み足）
%     figure 2   : 試行別のピーク Fz の散布図（踏み込み足）
%     figure 3〜6: 条件別の Fz 時系列（全 Go 試行を重ね描き）
%
% 入力:
%   x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults<ID>.mat
%       → SingleTrialResultArray
%         （BWBase / PeakFz1 / PeakFz2 と、30 Hz フィルタ後の波形 Fz1Filt / Fz2Filt を持つ）
%   x3_DataChecked/Data<ID>.mat
%       → FrameRate・AnalogFs（キュー時刻をアナログのサンプル番号に直すために必要）
%
% 備考:
%   - 床反力の計算はすべて m3_analyze_single_trial.m が済ませている。
%     このスクリプトは値を再計算しない（x7_2 が NetVelTop を使うのと同じ方針）。
%     従来は生波形から max を取り直しており、30 Hz フィルタの有無によって
%     x8_StatTable の統計値と食い違っていた。
%   - 時系列は波形全体を描き、表示範囲は XLim で決める。固定長で切り出すと
%     データ長を超えた試行が全て除外され、図が空になる（技術説明 §3.3）。
%   - NoGo・Stop 試行はスイングの抑制自体が課題なので集計に含めない。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject = 2 ;

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
ConditionColor     = {'g', 'b', 'r', 'm'} ;
nCondition         = numel(ConditionNameArray) ;

% スイングを抑制する試行は集計に含めない
ExcludedCueTextArray = {'NoGo', 'Stop'} ;

plotRange = [-1, 2] ;         % 時系列の表示範囲 [s]（キューを 0 とする）
YLimBW    = [-0.1, 1.6] ;     % 時系列の縦軸 [BW]（上下段で共通）

Prm = parameters ;

% -----------------------------------------------------------------------
% データ読み込み
% -----------------------------------------------------------------------
load(sprintf('x3_DataChecked/Data%02d', iSubject))
load(sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject))

nTrial = size(SingleTrialResultArray, 1) ;

% -----------------------------------------------------------------------
% ベースライン荷重の妥当性チェック（x8_make_stat_table.m と同一の判定）
%   静止時の Fz1+Fz2 は体重にほぼ一致するはず。大きく外れる試行は
%   プレートに正しく乗っていない計測不良で、正規化すると異常値になる。
%   BWBase は m3 が算出済みなので、生データを読み直す必要はない。
% -----------------------------------------------------------------------
BWArray = reshape([SingleTrialResultArray.BWBase], size(SingleTrialResultArray)) ;
bwRef   = median(BWArray(:), 'omitnan') ;
isBadBW = isnan(BWArray) | abs(BWArray - bwRef) > Prm.GRF.BWTolerance * bwRef ;

fprintf('=== Subject %02d ===\n', iSubject) ;
fprintf('体重の代表値: %.1f N（約 %.1f kg）\n', bwRef, bwRef/9.81) ;
for iCondition = 1:nCondition
    for iTrial = find(isBadBW(:, iCondition))'
        fprintf('除外（ベースライン荷重が異常）: %-8s 行%2d  bw = %.1f N\n', ...
            ConditionNameArray{iCondition}, iTrial, BWArray(iTrial, iCondition)) ;
    end
end

% -----------------------------------------------------------------------
% ピーク Fz を集める（m3 が算出した値を体重で正規化するだけ）
% -----------------------------------------------------------------------
PeakFz1 = nan(nTrial, nCondition) ;   % 後ろ足   [BW]
PeakFz2 = nan(nTrial, nCondition) ;   % 踏み込み足 [BW]

for iCondition = 1:nCondition
    for iTrial = 1:nTrial

        Result = SingleTrialResultArray(iTrial, iCondition) ;

        % NoGo・Stop 試行はスイングしないため除外する
        if ismember(Result.CueText, ExcludedCueTextArray)
            continue
        end

        % 計測不良・欠損・解析エラーの試行はここで一括して落ちる
        % （BWBase が NaN の試行は isBadBW が真になる）
        if isBadBW(iTrial, iCondition)
            continue
        end

        PeakFz1(iTrial, iCondition) = Result.PeakFz1 / Result.BWBase ;
        PeakFz2(iTrial, iCondition) = Result.PeakFz2 / Result.BWBase ;

    end % iTrial
end % iCondition

fprintf('ピーク Fz の集計完了\n') ;

% -----------------------------------------------------------------------
% figure 1：条件別ピーク Fz の箱ひげ図
% -----------------------------------------------------------------------
Fz1ByCondition   = cell(1, nCondition) ;   % 各条件の有効試行のピーク Fz1
Fz2ByCondition   = cell(1, nCondition) ;
TrialByCondition = cell(1, nCondition) ;   % 上記に対応する試行番号（行番号）

for iCondition = 1:nCondition
    isValid1 = ~isnan(PeakFz1(:, iCondition)) ;
    isValid2 = ~isnan(PeakFz2(:, iCondition)) ;
    Fz1ByCondition{iCondition}   = PeakFz1(isValid1, iCondition) ;
    Fz2ByCondition{iCondition}   = PeakFz2(isValid2, iCondition) ;
    TrialByCondition{iCondition} = find(isValid2) ;
end

meanFz1 = cellfun(@mean, Fz1ByCondition) ;
meanFz2 = cellfun(@mean, Fz2ByCondition) ;

% 有効試行数を表示する（x8_StatTable の n_PeakFz*_BW と一致するはず）
fprintf('\n--- 条件別の有効試行数と平均ピーク Fz ---\n') ;
for iCondition = 1:nCondition
    fprintf('  %-8s: n=%2d,  後ろ足 %.3f BW / 踏み込み足 %.3f BW\n', ...
        ConditionNameArray{iCondition}, numel(Fz2ByCondition{iCondition}), ...
        meanFz1(iCondition), meanFz2(iCondition)) ;
end

% タイトル用の「free: 1.23 / simple: 1.45 / ...」という文字列を組み立てる
titleFz1 = strjoin(arrayfun(@(i) sprintf('%s: %.2f', ConditionNameArray{i}, meanFz1(i)), ...
    1:nCondition, 'UniformOutput', false), ' / ') ;
titleFz2 = strjoin(arrayfun(@(i) sprintf('%s: %.2f', ConditionNameArray{i}, meanFz2(i)), ...
    1:nCondition, 'UniformOutput', false), ' / ') ;

% boxplot 用に、値のベクトルと条件名ラベルを縦に連結する
allFz1 = vertcat(Fz1ByCondition{:}) ;
allFz2 = vertcat(Fz2ByCondition{:}) ;
label1 = {} ;
label2 = {} ;
for iCondition = 1:nCondition
    condName = ConditionNameArray{iCondition} ;
    label1 = [label1 ; repmat({condName}, numel(Fz1ByCondition{iCondition}), 1)] ; %#ok<AGROW>
    label2 = [label2 ; repmat({condName}, numel(Fz2ByCondition{iCondition}), 1)] ; %#ok<AGROW>
end

figure(1) ; clf

subplot(1, 2, 1)
hasData1 = ~cellfun(@isempty, Fz1ByCondition) ;
boxplot(allFz1, label1, 'GroupOrder', ConditionNameArray(hasData1)) ;
ylabel('Peak Fz [BW]') ;
title('プレート１（後ろ足）') ;              % ← 1行にする
grid on

subplot(1, 2, 2)
hasData2 = ~cellfun(@isempty, Fz2ByCondition) ;
boxplot(allFz2, label2, 'GroupOrder', ConditionNameArray(hasData2)) ;
ylabel('Peak Fz [BW]') ;
title('プレート２（踏み込み足）') ;          % ← 1行にする
grid on

sgtitle(sprintf('Subject %02d：条件別ピーク鉛直床反力', iSubject)) ;

% -----------------------------------------------------------------------
% figure 2：試行別のピーク Fz の散布図（踏み込み足）
% -----------------------------------------------------------------------
figure(2) ; clf ; hold on

for iCondition = 1:nCondition
    scatter(TrialByCondition{iCondition}, Fz2ByCondition{iCondition}, 40, ...
        ConditionColor{iCondition}, 'filled', ...
        'DisplayName', ConditionNameArray{iCondition}) ;
end

hold off
xlabel('試行番号') ;
ylabel('Peak Fz [BW]（プレート２）') ;
title(sprintf('Subject %02d: 試行別のピーク鉛直分力（踏み込み足）', iSubject)) ;
legend('Location', 'best') ;
grid on

% -----------------------------------------------------------------------
% figure 3〜6：条件別の Fz 時系列（全 Go 試行を重ね描き）
%   m3 が保存したフィルタ後の波形をそのまま描く。波形全体を渡し、
%   表示範囲は XLim で決める（x7_2 の時系列グラフと同じ方針）。
% -----------------------------------------------------------------------
figByCondition    = 2 + (1:nCondition) ;   % figure 3, 4, 5, 6
nShownByCondition = zeros(1, nCondition) ;

for iFig = figByCondition
    figure(iFig) ; clf
end

for iCondition = 1:nCondition

    figNorm = figByCondition(iCondition) ;
    nShown  = 0 ;

    for iTrial = 1:nTrial

        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;

        if ~strcmp(Result.CueText, 'Go'),   continue, end
        if isBadBW(iTrial, iCondition),     continue, end
        if isempty(Result.Fz1Filt),         continue, end

        % キュー時刻をアナログのサンプル番号に直し、そこを 0 秒とする時間軸を作る
        tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs) ;
        tAnalog    = ((1:numel(Result.Fz1Filt))' - tCueAnalog) / Data.AnalogFs ;

        Fz1_norm = Result.Fz1Filt / Result.BWBase ;   % [BW]
        Fz2_norm = Result.Fz2Filt / Result.BWBase ;

        nShown = nShown + 1 ;

        % 凡例は各条件の1本目にだけ付ける
        if nShown == 1
            visArg = {'DisplayName', ConditionNameArray{iCondition}} ;
        else
            visArg = {'HandleVisibility', 'off'} ;
        end

        figure(figNorm)
        subplot(2, 1, 1) ; hold on
        plot(tAnalog, Fz1_norm, '-', 'Color', ConditionColor{iCondition}, ...
            'LineWidth', 0.8, visArg{:}) ;

        subplot(2, 1, 2) ; hold on
        plot(tAnalog, Fz2_norm, '-', 'Color', ConditionColor{iCondition}, ...
            'LineWidth', 0.8, visArg{:}) ;

    end % iTrial

    nShownByCondition(iCondition) = nShown ;

end % iCondition

% 条件ごとの装飾（タイトルに条件名と試行数を入れる）
for iCondition = 1:nCondition

    condName = ConditionNameArray{iCondition} ;
    figNorm  = figByCondition(iCondition) ;
    nShown   = nShownByCondition(iCondition) ;

    figure(figNorm)

    subplot(2, 1, 1) ; hold off
    lineplot(0, 'v', 'k--') ;
    set(gca, 'XLim', plotRange, 'YLim', YLimBW) ;
    xlabel('LED からの時間 [s]') ; ylabel('Fz [BW]') ;
    title(sprintf('プレート１（後ろ足）— 正規化後（Go %d 試行）', nShown)) ;
    legend('Location', 'northwest') ; grid on

    subplot(2, 1, 2) ; hold off
    lineplot(0, 'v', 'k--') ;
    set(gca, 'XLim', plotRange, 'YLim', YLimBW) ;
    xlabel('LED からの時間 [s]') ; ylabel('Fz [BW]') ;
    title(sprintf('プレート２（踏み込み足）— 正規化後（Go %d 試行）', nShown)) ;
    legend('Location', 'northwest') ; grid on

    sgtitle(sprintf('Subject %02d  %s条件：床反力 Fz の時系列', iSubject, condName)) ;

end
