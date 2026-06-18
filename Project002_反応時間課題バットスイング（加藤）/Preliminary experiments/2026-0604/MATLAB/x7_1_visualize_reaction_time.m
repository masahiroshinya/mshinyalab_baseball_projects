clear
close all
clc

iSubject = 2;

filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject);
load(filePath)

% free条件
mask_free    = ResultsTable.Condition == "free" & ResultsTable.CueText == "Go";
RT_free      = ResultsTable.RT_ms(mask_free);
Trial_free   = ResultsTable.Trial(mask_free);

nanMask_free = ~isnan(RT_free);
RT_free      = RT_free(nanMask_free);
Trial_free   = Trial_free(nanMask_free);

% simple条件
mask_simple    = ResultsTable.Condition == "simple" & ResultsTable.CueText == "Go";
RT_simple      = ResultsTable.RT_ms(mask_simple);
Trial_simple   = ResultsTable.Trial(mask_simple);

nanMask_simple = ~isnan(RT_simple);
RT_simple      = RT_simple(nanMask_simple);
Trial_simple   = Trial_simple(nanMask_simple);

% gonogo条件
mask_gonogo    = ResultsTable.Condition == "gonogo" & ResultsTable.CueText == "Go";
RT_gonogo      = ResultsTable.RT_ms(mask_gonogo);
Trial_gonogo   = ResultsTable.Trial(mask_gonogo);

nanMask_gonogo = ~isnan(RT_gonogo);
RT_gonogo      = RT_gonogo(nanMask_gonogo);
Trial_gonogo   = Trial_gonogo(nanMask_gonogo);

mean_free   = mean(RT_free);
mean_simple = mean(RT_simple);
mean_gonogo = mean(RT_gonogo);

std_free   = std(RT_free);
std_simple = std(RT_simple);
std_gonogo = std(RT_gonogo);

% 箱ひげ図で条件間を比較
figure(1)
clf

allRT    = [RT_free ; RT_simple ; RT_gonogo];
alllabel = [repmat({'free'},   length(RT_free), 1); ...
            repmat({'simple'}, length(RT_simple), 1); ...
            repmat({'gonogo'}, length(RT_gonogo), 1)];

boxplot(allRT, alllabel, 'GroupOrder', {'free', 'simple', 'gonogo'});

ylabel('反応時間（ms）');
title(sprintf('Subject %02d：条件別反応時間\nfree：%.0f±%.0f ms / simple：%.0f±%.0f ms / gonogo：%.0f±%.0f ms', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo));
grid on

% 各試行の反応時間を散布図で確認する
figure(2)
clf

hold on

scatter(Trial_free,   RT_free  , 40, 'g', 'filled', 'DisplayName', 'free');
scatter(Trial_simple, RT_simple, 40, 'b', 'filled', 'DisplayName', 'simple');
scatter(Trial_gonogo, RT_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo');

hold off

xlabel('試行番号');
ylabel('反応時間（ms）');
title(sprintf('Subject %02d：条件別反応時間\nfree：%.0f±%.0f ms / simple：%.0f±%.0f ms / gonogo：%.0f±%.0f ms', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo));
legend('Location', 'best');
grid on