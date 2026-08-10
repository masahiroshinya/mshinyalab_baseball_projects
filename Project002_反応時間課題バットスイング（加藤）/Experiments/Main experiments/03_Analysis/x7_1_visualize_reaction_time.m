% x7_1_visualize_reaction_time.m
%
% 目的:
%   x7_MultiTrialAnalysisResultsChecked/ の ResultsTable から、
%   条件別の反応時間（RT）を箱ひげ図と散布図で可視化する。
%
% 備考:
%   RT はキュー提示を起点とするため、free 条件（キューなし）は対象外。

clear
close all
clc

iSubject = 1;

filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject);
load(filePath)

% RT を比較する条件（free はキューがないため含めない）
RTConditionArray = {'simple', 'gonogo', 'gostop'};
RTConditionColor = {'b', 'r', 'm'};
nRTCondition     = length(RTConditionArray);

RTByCondition    = cell(1, nRTCondition);   % 各条件の Go 試行の RT
TrialByCondition = cell(1, nRTCondition);   % 上記に対応する試行番号

for iCondition = 1:nRTCondition
    condName = RTConditionArray{iCondition};

    mask     = ResultsTable.Condition == condName & ResultsTable.CueText == "Go";
    RTArray  = ResultsTable.RT_ms(mask);
    TrialArray = ResultsTable.Trial(mask);

    nanMask  = ~isnan(RTArray);
    RTByCondition{iCondition}    = RTArray(nanMask);
    TrialByCondition{iCondition} = TrialArray(nanMask);
end

meanRT = cellfun(@mean, RTByCondition);
stdRT  = cellfun(@std,  RTByCondition);

% タイトル用の「simple：320±25 ms / ...」という文字列を組み立てる
titleText = strjoin(arrayfun(@(i) sprintf('%s：%.0f±%.0f ms', ...
    RTConditionArray{i}, meanRT(i), stdRT(i)), ...
    1:nRTCondition, 'UniformOutput', false), ' / ');

% 箱ひげ図で条件間を比較
figure(1)
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
title(sprintf('Subject %02d：条件別反応時間\n%s', iSubject, titleText));
grid on

% 各試行の反応時間を散布図で確認する
figure(2)
clf

hold on

for iCondition = 1:nRTCondition
    scatter(TrialByCondition{iCondition}, RTByCondition{iCondition}, 40, ...
        RTConditionColor{iCondition}, 'filled', 'DisplayName', RTConditionArray{iCondition});
end

hold off

xlabel('試行番号');
ylabel('反応時間（ms）');
title(sprintf('Subject %02d：条件別反応時間\n%s', iSubject, titleText));
legend('Location', 'best');
grid on
