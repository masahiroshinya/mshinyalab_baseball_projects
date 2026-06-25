% x7_3_visualize_grf.m
%
% 目的:
%   床反力（GRF: Ground Reaction Force）データを読み込み、
%   条件間の比較を可視化する。
%
% 入力:
%   （未定） --- 床反力データの取り込みフローは別途設計が必要
%   ※ 現状の x2_Data/ には GRF データは含まれていない
%
% 出力:
%   figure 3 --- 条件別 床反力の可視化（指標・形式は設計後に決定）
%
% 備考:
%   - GRF データはモーションキャプチャとは別センサー（フォースプレート等）のため、
%     x2_import_data.m の取り込みフローを拡張する必要がある
%   - 分析指標（ピーク値・積分値・タイミング等）は設計段階で決定する

clear
close all
clc

iSubject = 1;

load(sprintf('x2_Data/Data%02d', iSubject))

load(sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject))

ConditionNameArray = {'free', 'simple', 'gonogo'};
nCondition = length(ConditionNameArray);
nTrial     = size(DataArray, 1);

% 1試行のGRFを試しに計算
iTrial     = 1;
iCondition = 1;

Data   = DataArray(iTrial, iCondition);
Result = SingleTrialResultArray(iTrial, iCondition);

Fz1 = Data.Force1(:, 3);
Fz2 = Data.Force2(:, 3);

tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs);
fprintf('tCueAnalog = %dサンプル目（= %.3f 秒）\n', tCueAnalog, tCueAnalog/Data.AnalogFs);

staticEnd  = tCueAnalog - 1;
bw = mean(Fz1(1:staticEnd)) + mean(Fz2(1:staticEnd));
fprintf('推定体重: %.1f N（約 %.1f kg)\n', bw, bw/9.81);

Fz1_BW = Fz1 / bw;
Fz2_BW = Fz2 / bw;

swingEnd = min(tCueAnalog + round(2 * Data.AnalogFs), length(Fz1));
swingRange = tCueAnalog : swingEnd;

peakFz1 = max(Fz1_BW(swingRange));
peakFz2 = max(Fz2_BW(swingRange));
fprintf('ピークFz1 = %.3f BW\n', peakFz1);
fprintf('ピークFz2 = %.3f BW\n', peakFz2);

% 全試行のピークFzを計算してまとめる
PeakFz1 = nan(nTrial, nCondition);
PeakFz2 = nan(nTrial, nCondition);

for iCondition = 1:nCondition
    for iTrial     = 1:nTrial

    Data = DataArray(iTrial, iCondition);
    Result = SingleTrialResultArray(iTrial, iCondition);

    if ~isfield(Data, 'Force1') || isempty(Data.Force1)
        continue
    end

    Fz1 = Data.Force1(:, 3);
    Fz2 = Data.Force2(:, 3);
    
    if isnan(Result.TCueMarker)
        continue
    end
    tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs);
    if tCueAnalog < 2
        continue
    end

    bw = mean(Fz1(1 : tCueAnalog-1)) + mean(Fz2(1 : tCueAnalog-1));
    if bw <= 0
        continue
    end

    swingEnd = min(tCueAnalog + round(2 * Data.AnalogFs), length(Fz1));
    swingRange = tCueAnalog : swingEnd;

    PeakFz1(iTrial, iCondition) = max(Fz1(swingRange)) / bw;
    PeakFz2(iTrial, iCondition) = max(Fz2(swingRange)) / bw;

    end
end

fprintf('ピークFzの計算完了');

% 箱ひげ図
Fz1_free     = PeakFz1(~isnan(PeakFz1(:,1)), 1);
Fz1_simple   = PeakFz1(~isnan(PeakFz1(:,2)), 2);
Fz1_gonogo   = PeakFz1(~isnan(PeakFz1(:,3)), 3);

Fz2_free     = PeakFz2(~isnan(PeakFz2(:,1)), 1);
Fz2_simple   = PeakFz2(~isnan(PeakFz2(:,2)), 2);
Fz2_gonogo   = PeakFz2(~isnan(PeakFz2(:,3)), 3);

mean_Fz1_free   = mean(Fz1_free)  ; mean_Fz2_free    = mean(Fz2_free);
mean_Fz1_simple = mean(Fz1_simple); mean_Fz2_simple  = mean(Fz2_simple);
mean_Fz1_gonogo = mean(Fz1_gonogo); mean_Fz2_gonogo  = mean(Fz2_gonogo);

figure(1)
clf

subplot(1, 2, 1)

allFz1 = [Fz1_free  ; Fz1_simple  ; Fz1_gonogo];
label1 = [repmat({'free'}, length(Fz1_free), 1); ...
          repmat({'simple'}, length(Fz1_simple), 1); ...
          repmat({'gonogo'}, length(Fz1_gonogo), 1)];
boxplot(allFz1, label1, 'GroupOrder',{'free', 'simple', 'gonogo'});
ylabel('Peak Fz[BW]');
title(sprintf('プレート１（後ろ足）\nfree: %.2f / simple: %.2f / gonogo: %.2f', ...
    mean_Fz1_free, mean_Fz1_simple, mean_Fz1_gonogo));
grid on

subplot(1, 2, 2)

allFz2 = [Fz2_free  ; Fz2_simple  ; Fz2_gonogo];
label2 = [repmat({'free'}, length(Fz2_free), 1); ...
    repmat({'simple'}, length(Fz2_simple), 1); ...
    repmat({'gonogo'}, length(Fz2_gonogo), 1)];
boxplot(allFz2, label2, 'GroupOrder',{'free', 'simple', 'gonogo'});
ylabel('Peak Fz[BW]');
title(sprintf('プレート2（前の足）\nfree: %.2f / simple: %.2f / gonogo: %.2f', ...
    mean_Fz2_free, mean_Fz2_simple, mean_Fz2_gonogo));
grid on
          
% 散布図
figure(2)
clf

hold on

Trial_free   = find(~isnan(PeakFz2(:,1)));
Trial_simple = find(~isnan(PeakFz2(:,2)));
Trial_gonogo = find(~isnan(PeakFz2(:,3)));

scatter(Trial_free,   Fz2_free,   40, 'g', 'filled', 'DisplayName', 'free');
scatter(Trial_simple, Fz2_simple, 40, 'b', 'filled', 'DisplayName', 'simple');
scatter(Trial_gonogo, Fz2_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo');

hold off

xlabel('試行番号')
ylabel('Peak Fz[BW]（プレート２）');
title(sprintf('Subject %02d: 試行別のピーク垂直分力（踏み込み足）', iSubject));
legend('Location', 'best');
grid on

% GRF時系列
% GRF時系列
plotRange = [-1, 3];
fsAnalog  = DataArray(1, 1).AnalogFs;
nPlot     = round((plotRange(2) - plotRange(1)) * fsAnalog);
tPlot     = plotRange(1) + [0:nPlot-1] / fsAnalog;

condColors = {'g', 'b', 'r'};

figure(3); clf
figure(4); clf

for iCondition = 1:nCondition

    condName = ConditionNameArray{iCondition};

    Fz1_raw_cell  = {};
    Fz2_raw_cell  = {};
    Fz1_norm_cell = {};
    Fz2_norm_cell = {};

    for iTrial = 1:nTrial

        Data   = DataArray(iTrial, iCondition);
        Result = SingleTrialResultArray(iTrial, iCondition);

        if ~strcmp(Result.CueText, 'Go')
            continue
        end
        if isnan(Result.TCueMarker) || ~isfield(Data, 'Force1') || isempty(Data.Force1)
            continue
        end

        Fz1 = Data.Force1(:, 3);
        Fz2 = Data.Force2(:, 3);
        nAnalog    = length(Fz1);
        tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs);

        if tCueAnalog < 2
            continue
        end

        bw = mean(Fz1(1:tCueAnalog-1)) + mean(Fz2(1:tCueAnalog-1));
        if bw <= 0
            continue
        end

        iStart = tCueAnalog + round(plotRange(1) * fsAnalog);
        iEnd   = iStart + nPlot - 1;

        if iStart < 1 || iEnd > nAnalog
            continue
        end

        % 正規化前（N）
        Fz1_raw_cell{end+1}  = Data.Force1(iStart:iEnd, 3);
        Fz2_raw_cell{end+1}  = Data.Force2(iStart:iEnd, 3);

        % 正規化後（BW）
        Fz1_norm_cell{end+1} = Data.Force1(iStart:iEnd, 3) / bw;
        Fz2_norm_cell{end+1} = Data.Force2(iStart:iEnd, 3) / bw;

    end

    if isempty(Fz1_raw_cell)
        continue
    end

    nValid        = length(Fz1_raw_cell);
    Fz1_raw_mean  = mean(cell2mat(Fz1_raw_cell),  2)';
    Fz2_raw_mean  = mean(cell2mat(Fz2_raw_cell),  2)';
    Fz1_norm_mean = mean(cell2mat(Fz1_norm_cell), 2)';
    Fz2_norm_mean = mean(cell2mat(Fz2_norm_cell), 2)';

    % Figure 3：正規化前（N）
    figure(3)
    subplot(2, 1, 1); hold on
    plot(tPlot, Fz1_raw_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid));
    subplot(2, 1, 2); hold on
    plot(tPlot, Fz2_raw_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid));

    % Figure 4：正規化後（BW）
    figure(4)
    subplot(2, 1, 1); hold on
    plot(tPlot, Fz1_norm_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid));
    subplot(2, 1, 2); hold on
    plot(tPlot, Fz2_norm_mean, condColors{iCondition}, 'LineWidth', 1.5, ...
        'DisplayName', sprintf('%s (n=%d)', condName, nValid));

end

% Figure 3 の装飾（正規化前・YLim は自動）
figure(3)
subplot(2, 1, 1)
lineplot(0, 'v', 'k--');
set(gca, 'XLim', plotRange);
xlabel('LEDからの時間 [s]'); ylabel('Fz [N]');
title(sprintf('Subject %02d  プレート１（後ろ足）— 条件別平均（正規化前）', iSubject));
legend('Location', 'northwest'); grid on

subplot(2, 1, 2)
lineplot(0, 'v', 'k--');
set(gca, 'XLim', plotRange);
xlabel('LEDからの時間 [s]'); ylabel('Fz [N]');
title(sprintf('Subject %02d  プレート２（前の足）— 条件別平均（正規化前）', iSubject));
legend('Location', 'northwest'); grid on

% Figure 4 の装飾（正規化後・YLim 固定）
figure(4)
subplot(2, 1, 1)
lineplot(0, 'v', 'k--');
set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]);
xlabel('LEDからの時間 [s]'); ylabel('Fz [BW]');
title(sprintf('Subject %02d  プレート１（後ろ足）— 条件別平均（正規化後）', iSubject));
legend('Location', 'northwest'); grid on

subplot(2, 1, 2)
lineplot(0, 'v', 'k--');
set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]);
xlabel('LEDからの時間 [s]'); ylabel('Fz [BW]');
title(sprintf('Subject %02d  プレート２（前の足）— 条件別平均（正規化後）', iSubject));
legend('Location', 'northwest'); grid on

