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

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'};
nCondition = length(ConditionNameArray);
nTrial     = size(DataArray, 1);

% スイングを抑制する試行は集計に含めない
ExcludedCueTextArray = {'NoGo', 'Stop'};

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

% ---- パス1: 全試行のベースライン荷重を集め、異常な試行を洗い出す ----
Prm     = parameters ;
BWArray = nan(nTrial, nCondition) ;
for iCondition = 1:nCondition
    for iTrial = 1:nTrial
        Data   = DataArray(iTrial, iCondition) ;
        Result = SingleTrialResultArray(iTrial, iCondition) ;
        if ~isfield(Data, 'Force1') || isempty(Data.Force1), continue, end
        if isnan(Result.TCueMarker), continue, end
        tCueAnalog = round(Result.TCueMarker / Data.FrameRate * Data.AnalogFs) ;
        if tCueAnalog < 2, continue, end
        BWArray(iTrial, iCondition) = mean(Data.Force1(1:tCueAnalog-1, 3)) ...
            + mean(Data.Force2(1:tCueAnalog-1, 3)) ;
    end
end
bwRef   = median(BWArray(:), 'omitnan') ;                        % 体重の代表値 [N]
isBadBW = abs(BWArray - bwRef) > Prm.GRF.BWTolerance * bwRef ;

fprintf('体重の代表値: %.1f N（約 %.1f kg）\n', bwRef, bwRef/9.81) ;
for iCondition = 1:nCondition
    for iTrial = find(isBadBW(:, iCondition))'
        fprintf('除外（ベースライン荷重が異常）: %s 行%d  bw = %.1f N\n', ...
            ConditionNameArray{iCondition}, iTrial, BWArray(iTrial, iCondition)) ;
    end
end

% 全試行のピークFzを計算してまとめる
PeakFz1 = nan(nTrial, nCondition);
PeakFz2 = nan(nTrial, nCondition);

for iCondition = 1:nCondition
    for iTrial     = 1:nTrial

    Data = DataArray(iTrial, iCondition);
    Result = SingleTrialResultArray(iTrial, iCondition);

    % NoGo・Stop 試行はスイングしないため除外する
    if ismember(Result.CueText, ExcludedCueTextArray)
        continue
    end

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

    if isBadBW(iTrial, iCondition)
        continue
    end

    swingEnd = min(tCueAnalog + round(2 * Data.AnalogFs), length(Fz1));
    swingRange = tCueAnalog : swingEnd;

    PeakFz1(iTrial, iCondition) = max(Fz1(swingRange)) / bw;
    PeakFz2(iTrial, iCondition) = max(Fz2(swingRange)) / bw;

    end
end

fprintf('ピークFzの計算完了');

% 箱ひげ図（条件数に依存しないよう、条件ループで作る）
Fz1ByCondition = cell(1, nCondition);   % 各条件の有効試行のピーク Fz1
Fz2ByCondition = cell(1, nCondition);
TrialByCondition = cell(1, nCondition); % 上記に対応する試行番号（行番号）

for iCondition = 1:nCondition
    isValid1 = ~isnan(PeakFz1(:, iCondition));
    isValid2 = ~isnan(PeakFz2(:, iCondition));
    Fz1ByCondition{iCondition}   = PeakFz1(isValid1, iCondition);
    Fz2ByCondition{iCondition}   = PeakFz2(isValid2, iCondition);
    TrialByCondition{iCondition} = find(isValid2);
end

meanFz1 = cellfun(@mean, Fz1ByCondition);
meanFz2 = cellfun(@mean, Fz2ByCondition);

% タイトル用の「free: 1.23 / simple: 1.45 / ...」という文字列を組み立てる
titleFz1 = strjoin(arrayfun(@(i) sprintf('%s: %.2f', ConditionNameArray{i}, meanFz1(i)), ...
    1:nCondition, 'UniformOutput', false), ' / ');
titleFz2 = strjoin(arrayfun(@(i) sprintf('%s: %.2f', ConditionNameArray{i}, meanFz2(i)), ...
    1:nCondition, 'UniformOutput', false), ' / ');

% boxplot 用に、値のベクトルと条件名ラベルを縦に連結する
allFz1 = vertcat(Fz1ByCondition{:});
allFz2 = vertcat(Fz2ByCondition{:});
label1 = {};
label2 = {};
for iCondition = 1:nCondition
    condName = ConditionNameArray{iCondition};
    label1 = [label1 ; repmat({condName}, length(Fz1ByCondition{iCondition}), 1)]; %#ok<AGROW>
    label2 = [label2 ; repmat({condName}, length(Fz2ByCondition{iCondition}), 1)]; %#ok<AGROW>
end

figure(1)
clf

subplot(1, 2, 1)

% データがない条件を GroupOrder に含めると boxplot がエラーになるため除く
hasData1 = ~cellfun(@isempty, Fz1ByCondition);
boxplot(allFz1, label1, 'GroupOrder', ConditionNameArray(hasData1));
ylabel('Peak Fz[BW]');
title(sprintf('プレート１（後ろ足）\n%s', titleFz1));
grid on

subplot(1, 2, 2)

hasData2 = ~cellfun(@isempty, Fz2ByCondition);
boxplot(allFz2, label2, 'GroupOrder', ConditionNameArray(hasData2));
ylabel('Peak Fz[BW]');
title(sprintf('プレート2（前の足）\n%s', titleFz2));
grid on

% 散布図
figure(2)
clf

hold on

scatterColors = {'g', 'b', 'r', 'm'};

for iCondition = 1:nCondition
    scatter(TrialByCondition{iCondition}, Fz2ByCondition{iCondition}, 40, ...
        scatterColors{iCondition}, 'filled', 'DisplayName', ConditionNameArray{iCondition});
end

hold off

xlabel('試行番号')
ylabel('Peak Fz[BW]（プレート２）');
title(sprintf('Subject %02d: 試行別のピーク垂直分力（踏み込み足）', iSubject));
legend('Location', 'best');
grid on

% GRF時系列（体重正規化後のみ。プレート１＝後ろ足／プレート２＝踏み込み足を上下に並べる）
%   x7_2 の時系列グラフと同じ方針で、全試行を条件色の実線で重ね描きする（平均線は描かない）。
plotRange = [-1, 2] ;   % [-1, 3] から変更
fsAnalog  = DataArray(1, 1).AnalogFs;
nPlot     = round((plotRange(2) - plotRange(1)) * fsAnalog);
tPlot     = plotRange(1) + [0:nPlot-1] / fsAnalog;

condColors = {'g', 'b', 'r', 'm'};

figNormByCondition = 2 + (1:nCondition);   % 正規化後（BW）：条件ごとに1枚
nShownByCondition  = zeros(1, nCondition);

for iFig = figNormByCondition
    figure(iFig); clf
end

for iCondition = 1:nCondition

    figNorm = figNormByCondition(iCondition);
    nShown  = 0;

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

        if isBadBW(iTrial, iCondition)
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

        Fz1_norm = Fz1(iStart:iEnd) / bw;   % 正規化後（BW）
        Fz2_norm = Fz2(iStart:iEnd) / bw;

        nShown = nShown + 1;

        % 凡例は各条件の1本目にだけ付ける
        if nShown == 1
            visArg = {'DisplayName', ConditionNameArray{iCondition}};
        else
            visArg = {'HandleVisibility', 'off'};
        end

        figure(figNorm)
        subplot(2, 1, 1); hold on
        plot(tPlot, Fz1_norm, '-', 'Color', condColors{iCondition}, ...
            'LineWidth', 0.8, visArg{:});

        subplot(2, 1, 2); hold on
        plot(tPlot, Fz2_norm, '-', 'Color', condColors{iCondition}, ...
            'LineWidth', 0.8, visArg{:});

    end % iTrial

    nShownByCondition(iCondition) = nShown;

end % iCondition

% 条件ごとの装飾（タイトルに条件名と試行数を入れる）
for iCondition = 1:nCondition
    condName = ConditionNameArray{iCondition};
    figNorm  = figNormByCondition(iCondition);
    nShown   = nShownByCondition(iCondition);

    figure(figNorm)
    subplot(2, 1, 1); hold off
    lineplot(0, 'v', 'k--');
    set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]);
    xlabel('LEDからの時間 [s]'); ylabel('Fz [BW]');
    title(sprintf('プレート１（後ろ足）— 正規化後（Go %d 試行）', nShown));
    legend('Location', 'northwest'); grid on

    subplot(2, 1, 2); hold off
    lineplot(0, 'v', 'k--');
    set(gca, 'XLim', plotRange, 'YLim', [-0.1, 1.6]);
    xlabel('LEDからの時間 [s]'); ylabel('Fz [BW]');
    title(sprintf('プレート２（踏み込み足）— 正規化後（Go %d 試行）', nShown));
    legend('Location', 'northwest'); grid on

    sgtitle(sprintf('Subject %02d  %s条件：床反力 Fz の時系列', iSubject, condName));
end
