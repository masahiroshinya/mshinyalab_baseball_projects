% x7_2_visualize_swing_speed.m
%
% 目的:
%   x7_MultiTrialAnalysisResultsChecked/ の確認済みマルチ試行結果から
%   スイングスピード（PeakVelTop: バット先端マーカーの最大並進速度）を読み込み、
%   条件間の比較を可視化する。
%
% 入力:
%   x7_MultiTrialAnalysisResultsChecked/MultiTrialResults<SubjectID>.mat
%   変数: ResultsTable（列: Subject, Condition, Trial, CueText, PeakVelTop, ...）
%
% 出力:
%   figure 1 --- 条件別 最大バット先端速度の箱ひげ図（free / simple / gonogo）
%   figure 2 --- 試行ごとの最大バット先端速度の散布図
%
% 備考:
%   - PeakVelTop の単位は m/s（top マーカーの合成速度のピーク値）
%   - 角速度（PeakOmegaDeg）による指標は廃止した（00 §2 の決定）
%   - gonogo 条件では NoGo 試行（CueText == 'NoGo'）を除外して集計する
%   - PeakVelTop が NaN の試行も除外する

clear
close all
clc

iSubject = 1;

filePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject);
load(filePath)

% free条件
mask_free  = ResultsTable.Condition == "free" & ResultsTable.CueText == "Go";
Vel_free   = ResultsTable.PeakVelTop(mask_free);
Trial_free = ResultsTable.Trial(mask_free);

nanMask_free = ~isnan(Vel_free);
Vel_free     = Vel_free(nanMask_free);
Trial_free   = Trial_free(nanMask_free);

% simple条件
mask_simple  = ResultsTable.Condition == "simple" & ResultsTable.CueText == "Go";
Vel_simple   = ResultsTable.PeakVelTop(mask_simple);
Trial_simple = ResultsTable.Trial(mask_simple);

nanMask_simple = ~isnan(Vel_simple);
Vel_simple     = Vel_simple(nanMask_simple);
Trial_simple   = Trial_simple(nanMask_simple);

% gonogo条件
mask_gonogo  = ResultsTable.Condition == "gonogo" & ResultsTable.CueText == "Go";
Vel_gonogo   = ResultsTable.PeakVelTop(mask_gonogo);
Trial_gonogo = ResultsTable.Trial(mask_gonogo);

nanMask_gonogo = ~isnan(Vel_gonogo);
Vel_gonogo     = Vel_gonogo(nanMask_gonogo);
Trial_gonogo   = Trial_gonogo(nanMask_gonogo);

mean_free   = mean(Vel_free);
mean_simple = mean(Vel_simple);
mean_gonogo = mean(Vel_gonogo);

std_free   = std(Vel_free);
std_simple = std(Vel_simple);
std_gonogo = std(Vel_gonogo);

% 箱ひげ図で条件間を比較
figure(1)
clf

allVel   = [Vel_free ; Vel_simple ; Vel_gonogo];
alllabel = [repmat({'free'},   length(Vel_free), 1); ...
    repmat({'simple'}, length(Vel_simple), 1); ...
    repmat({'gonogo'}, length(Vel_gonogo), 1)];

boxplot(allVel, alllabel, 'GroupOrder', {'free', 'simple', 'gonogo'});

ylabel('先端マーカーピーク合成速度（m/s）');
title(sprintf('Subject %02d：先端マーカーピーク合成速度\nfree：%.1f±%.1f m/s / simple：%.1f±%.1f m/s / gonogo：%.1f±%.1f m/s', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo));
grid on

% 各試行のスイングスピードを散布図で確認する
figure(2)
clf

hold on

scatter(Trial_free,   Vel_free  , 40, 'g', 'filled', 'DisplayName', 'free');
scatter(Trial_simple, Vel_simple, 40, 'b', 'filled', 'DisplayName', 'simple');
scatter(Trial_gonogo, Vel_gonogo, 40, 'r', 'filled', 'DisplayName', 'gonogo');

hold off

xlabel('試行番号');
ylabel('先端マーカーピーク合成速度（m/s）');
title(sprintf('Subject %02d：先端マーカーピーク合成速度\nfree：%.1f±%.1f m/s / simple：%.1f±%.1f m/s / gonogo：%.1f±%.1f m/s', ...
    iSubject, mean_free, std_free, mean_simple, std_simple, mean_gonogo, std_gonogo));
legend('Location', 'best');
grid on
