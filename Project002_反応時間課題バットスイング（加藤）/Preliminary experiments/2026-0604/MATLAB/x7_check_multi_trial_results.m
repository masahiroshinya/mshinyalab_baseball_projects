% x7_check_multi_trial_results.m
%
% 目的:
%   x6 で保存したマルチ試行結果テーブルを読み込み、
%   集計サマリーとグラフで結果を目視確認する。
%   確認が終わったら y/n で x7_MultiTrialAnalysisResultsChecked/ に保存する。
%   ワークフロー Step 7 に対応。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject = 1 ;

% -----------------------------------------------------------------------
% データ読み込み
% -----------------------------------------------------------------------
loadPath = sprintf('x6_MultiTrialAnalysisResults/MultiTrialResults%02d', iSubject) ;
load(loadPath)  % → ResultsTable が読み込まれる

fprintf('=== 読み込み完了: %d 試行 ===\n\n', height(ResultsTable)) ;
disp(ResultsTable)

% -----------------------------------------------------------------------
% 集計サマリー表示
% -----------------------------------------------------------------------
fprintf('\n--- 条件別 RT サマリー（Go 試行・スイング検出あり）---\n') ;

GoRows  = ResultsTable.CueText == "Go" & ~isnan(ResultsTable.RT_ms) ;
GoTable = ResultsTable(GoRows, :) ;

goConditions = unique(GoTable.Condition) ;
for k = 1:numel(goConditions)
    cond    = goConditions(k) ;
    idx     = GoTable.Condition == cond ;
    rt_vals = GoTable.RT_ms(idx) ;
    fprintf('  %s: n=%d, 平均=%.1f ms, SD=%.1f ms\n', ...
        char(cond), sum(idx), mean(rt_vals), std(rt_vals)) ;
end

fprintf('\n--- NoGo 抑制率（gonogo 条件）---\n') ;
nogoRows  = ResultsTable.CueText == "NoGo" & ResultsTable.Condition == "gonogo" ;
nogoTable = ResultsTable(nogoRows, :) ;
if height(nogoTable) > 0
    nNoGo      = height(nogoTable) ;
    nInhibited = sum(isnan(nogoTable.RT_ms)) ;
    fprintf('  NoGo 試行数: %d, 抑制成功: %d, 抑制率: %.1f%%\n', ...
        nNoGo, nInhibited, nInhibited/nNoGo*100) ;
else
    fprintf('  NoGo 試行が見つかりませんでした。\n') ;
end

% -----------------------------------------------------------------------
% グラフ表示
% -----------------------------------------------------------------------
figure(1) ; clf

% ---- 条件別 RT 箱ひげ図（Go 試行）----
subplot(1,2,1)
nCond    = numel(goConditions) ;
cond_rt  = [] ;
grp_idx  = [] ;
lbl_cell = {} ;
for k = 1:nCond
    cond = goConditions(k) ;
    idx  = GoTable.Condition == cond ;
    rt   = GoTable.RT_ms(idx) ;
    cond_rt  = [cond_rt  ; rt] ;                     %#ok<AGROW>
    grp_idx  = [grp_idx  ; repmat(k, sum(idx), 1)] ; %#ok<AGROW>
    lbl_cell{k} = char(cond) ;
end
if ~isempty(cond_rt)
    boxplot(cond_rt, grp_idx, 'Labels', lbl_cell) ;
end
ylabel('反応時間 (ms)') ;
title('条件別 RT（Go 試行）') ;
grid on

% ---- 条件別 最大角速度 箱ひげ図（全試行）----
subplot(1,2,2)
allConditions = unique(ResultsTable.Condition) ;
cond_omega = [] ;
grp_idx2   = [] ;
lbl_cell2  = {} ;
for k = 1:numel(allConditions)
    cond  = allConditions(k) ;
    idx   = ResultsTable.Condition == cond ;
    omega = ResultsTable.PeakOmegaDeg(idx) ;
    cond_omega = [cond_omega ; omega] ;                   %#ok<AGROW>
    grp_idx2   = [grp_idx2  ; repmat(k, sum(idx), 1)] ;  %#ok<AGROW>
    lbl_cell2{k} = char(cond) ;
end
if ~isempty(cond_omega)
    boxplot(cond_omega, grp_idx2, 'Labels', lbl_cell2) ;
end
ylabel('最大角速度 (deg/s)') ;
title('条件別 スイングスピード（全試行）') ;
grid on
y
sgtitle(sprintf(['マルチ試行分析結果 Subject %02d'], iSubject)) ;

% -----------------------------------------------------------------------
% 確認後に保存
% -----------------------------------------------------------------------
answer = input('\nグラフと集計を確認しました。x7 に保存しますか？ [y/n]: ', 's') ;
if strcmpi(answer, 'y')
    savePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject) ;
    save(savePath, 'ResultsTable') ;
    fprintf('保存完了: %s.mat\n', savePath) ;
else
    fprintf('保存をキャンセルしました。\n') ;
end
