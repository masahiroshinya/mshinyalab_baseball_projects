% x7_1_visualize_reaction_time.m
%
% 目的:
%   x7_MultiTrialAnalysisResultsChecked/ の ResultsTable から、
%   条件別の反応時間（RT）を箱ひげ図と散布図で可視化する。
%
% 備考:
%   free 条件はキューへの反応を求めていないため報告対象ではないが、
%   検出の妥当性を確認するために可視化には含める。


clear
close all
clc

iSubject = 1;

filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject);
load(filePath)

% RT を比較する条件。free はキューへの反応を求めていないため報告対象ではないが、
% 検出が正しく働いているかの確認用に可視化に含める（他条件より明確に遅いはず）。
RTConditionArray = {'free', 'simple', 'gonogo', 'gostop'};
RTConditionColor = {'g', 'b', 'r', 'm'};
nRTCondition     = length(RTConditionArray);

% 2方式を同じ形式で描く。figure 1・2 = Nasu 方式、figure 3・4 = 床反力方式。
RTMethodArray = {'RTHand_ms', 'RTForce_ms'};
RTMethodLabel = {'Nasu 方式（手部速度）', '床反力方式（後ろ足 Fz1）'};

for iMethod = 1:numel(RTMethodArray)

    col = RTMethodArray{iMethod};

    RTByCondition    = cell(1, nRTCondition);   % 各条件の Go 試行の RT
    TrialByCondition = cell(1, nRTCondition);   % 上記に対応する試行番号

    for iCondition = 1:nRTCondition
        mask       = ResultsTable.Condition == RTConditionArray{iCondition} ...
                   & ResultsTable.CueText == "Go";
        RTArray    = ResultsTable.(col)(mask);
        TrialArray = ResultsTable.Trial(mask);

        nanMask = ~isnan(RTArray);
        RTByCondition{iCondition}    = RTArray(nanMask);
        TrialByCondition{iCondition} = TrialArray(nanMask);
    end

    meanRT = cellfun(@mean, RTByCondition);
    stdRT  = cellfun(@std,  RTByCondition);

    % タイトル用の「simple：583±42 ms / ...」という文字列を組み立てる
    titleText = strjoin(arrayfun(@(i) sprintf('%s：%.0f±%.0f ms', ...
        RTConditionArray{i}, meanRT(i), stdRT(i)), ...
        1:nRTCondition, 'UniformOutput', false), ' / ');

    % 箱ひげ図で条件間を比較
    figure(2*iMethod - 1)
    clf

    allRT    = vertcat(RTByCondition{:});
    alllabel = {};
    for iCondition = 1:nRTCondition
        alllabel = [alllabel ; repmat(RTConditionArray(iCondition), ...
            length(RTByCondition{iCondition}), 1)]; %#ok<AGROW>
    end

    % データがない条件を GroupOrder に含めると boxplot がエラーになるため除く
    hasData = ~cellfun(@isempty, RTByCondition);
    boxplot(allRT, alllabel, 'GroupOrder', RTConditionArray(hasData));

    ylabel('反応時間（ms）');
    title(sprintf('Subject %02d：条件別反応時間 — %s\n%s', ...
        iSubject, RTMethodLabel{iMethod}, titleText));
    grid on

    % 各試行の反応時間を散布図で確認する
    figure(2*iMethod)
    clf
    hold on

    for iCondition = 1:nRTCondition
        scatter(TrialByCondition{iCondition}, RTByCondition{iCondition}, 40, ...
            RTConditionColor{iCondition}, 'filled', ...
            'DisplayName', RTConditionArray{iCondition});
    end

    hold off

    xlabel('試行番号');
    ylabel('反応時間（ms）');
    title(sprintf('Subject %02d：条件別反応時間 — %s\n%s', ...
        iSubject, RTMethodLabel{iMethod}, titleText));
    legend('Location', 'best');
    grid on

end

% 2方式の対応関係。対角線より上に乗れば床反力が先行していることを意味する。
figure(5)
clf
hold on

for iCondition = 1:nRTCondition
    mask = ResultsTable.Condition == RTConditionArray{iCondition} ...
         & ResultsTable.CueText == "Go";
    scatter(ResultsTable.RTForce_ms(mask), ResultsTable.RTHand_ms(mask), 40, ...
        RTConditionColor{iCondition}, 'filled', ...
        'DisplayName', RTConditionArray{iCondition});
end

axisLim = [0, 1250];
plot(axisLim, axisLim, 'k--', 'DisplayName', 'y = x');

hold off

axis equal
xlim(axisLim); ylim(axisLim);
xlabel('RTForce（床反力方式）[ms]');
ylabel('RTHand（Nasu 方式）[ms]');
title(sprintf('Subject %02d：2方式の対応（Go 試行）', iSubject));
legend('Location', 'best');
grid on
