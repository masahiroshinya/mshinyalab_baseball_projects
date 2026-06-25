% x7_2_visualize_swing_speed.m
%
% 目的:
%   x7_MultiTrialAnalysisResultsChecked/ の確認済みマルチ試行結果から
%   スイングスピード（PeakOmegaDeg: 最大バット角速度）を読み込み、
%   条件間の比較を可視化する。
%
% 入力:
%   x7_MultiTrialAnalysisResultsChecked/MultiTrialResults<SubjectID>.mat
%   変数: ResultsTable（列: Subject, Condition, Trial, CueText, PeakOmegaDeg, ...）
%
% 出力:
%   figure 2 --- 条件別 最大角速度の箱ひげ図（free / simple / gonogo）
%
% 備考:
%   - PeakOmegaDeg の単位は deg/s（Shinya 角速度法による最大値）
%   - gonogo 条件では NoGo 試行（CueText == 'NoGo'）を除外して集計する
%   - PeakOmegaDeg が NaN の試行も除外する

clear
close all
clc

iSubject = 1;

filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject);
load(filePath)

% free条件
mask_free    = ResultsTable.Condition == "free" & ResultsTable.CueText == "Go";
Omega_free   = ResultsTable.PeakOmegaDeg(mask_free);
Trial_free   = ResultsTable.Trial(mask_free);

nanMask_free = ~isnan(Omega_free);
Omega_free   = Omega_free(nanMask_free);
Trial_free   = Trial_free(nanMask_free);

% simple条件
mask_simple    = ResultsTable.Condition == "simple" & ResultsTable.CueText == "Go";
Omega_simple   = ResultsTable.PeakOmegaDeg(mask_simple);
Trial_simple   = ResultsTable.Trial(mask_simple);

nanMask_simple = ~isnan(Omega_simple);
Omega_simple   = Omega_simple(nanMask_simple);
Trial_simple   = Trial_simple(nanMask_simple);

% gonogo条件
mask_gonogo    = ResultsTable.Condition == "gonogo" & ResultsTable.CueText == "Go";
Omega_gonogo   = ResultsTable.PeakOmegaDeg(mask_gonogo);
Trial_gonogo   = ResultsTable.Trial(mask_gonogo);

nanMask_gonogo = ~isnan(Omega_gonogo);
Omega_gonogo   = Omega_gonogo(nanMask_gonogo);
Trial_gonogo   = Trial_gonogo(nanMask_gonogo);

mean_free   = mean(Omega_free);
mean_simple = mean(Omega_simple);
mean_gonogo = mean(Omega_gonogo);

std_free   = std(Omega_free);
std_simple = std(Omega_simple);
std_gonogo = std(Omega_gonogo);

% 箱ひげ図で条件間を比較
figure(1)
clf

allOmega = [Omega_free ; Omega_simple ; Omega_gonogo];
alllabel = [repmat({'free'},   length(Omega_free), 1); ...
    repmat({'simple'}, length(Omega_simple), 1); ...
    repmat({'gonogo'}, length(Omega_gonogo), 1)];

boxplot(allOmega, alllabel, 'GroupOrder', {'free', 'simple', 'gonogo'});

ylabel('最大角速度（deg/s）');
title(sprintf('Subject %02d：条件別スイングスピード\nfree：%.0f±%.0f deg/s / simple：%.0f±%.0f deg/s / gonogo：%.0f±%.0f deg/s', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo));
grid on

% 各試行のスイングスピードを散布図で確認する
figure(2)
clf

hold on

scatter(Trial_free,   Omega_free  , 40, 'g', 'filled', 'DisplayName', 'free');
scatter(Trial_simple, Omega_simple, 40, 'b', 'filled', 'DisplayName', 'simple');
scatter(Trial_gonogo, Omega_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo');

hold off

xlabel('試行番号');
ylabel('最大角速度（deg/s）');
title(sprintf('Subject %02d：条件別スイングスピード\nfree：%.0f±%.0f deg/s / simple：%.0f±%.0f deg/s / gonogo：%.0f±%.0f deg/s', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo));
legend('Location', 'best');
grid on