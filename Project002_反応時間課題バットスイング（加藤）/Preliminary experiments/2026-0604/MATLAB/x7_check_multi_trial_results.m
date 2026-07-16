% x7_check_multi_trial_results.m
%
% 目的:
%   x6 で保存したマルチ試行結果テーブルを読み込み、
%   集計サマリーとグラフで結果を目視確認する。
%   確認が終わったら y/n で x7_MultiTrialAnalysisResultsChecked/ に保存する。
%   ワークフロー Step 7 に対応。
%
% 備考:
%   角速度は廃止した（00 §2）。スイングスピードは PeakVelTop [m/s] で見る。
%   RT は 00 で検出信号を検討中のため現在すべて NaN。RT 系の集計は停止している。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
iSubject = 2 ;

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
% RT は現在すべて NaN（角速度検出を廃止し、新しい検出信号は 00 で検討中）。
% この状態で「RT が NaN ＝ 抑制成功」と数えると抑制率が常に 100% になり、
% 被験者が抑制したかのように見えてしまうため、RT 系の集計は停止する。
if all(isnan(ResultsTable.RT_ms))
    fprintf('\n--- RT サマリー：停止中 ---\n') ;
    fprintf('  RT は現在すべて NaN です（00 で検出信号を検討中）。\n') ;
    fprintf('  NoGo 抑制率も RT に依存するため算出しません。\n') ;
else
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
end

% -----------------------------------------------------------------------
% 条件別 PeakVelTop サマリー（Go 試行）
% -----------------------------------------------------------------------
fprintf('\n--- 条件別 バット先端速度サマリー（Go 試行）---\n') ;
GoVelRows  = ResultsTable.CueText == "Go" & ~isnan(ResultsTable.PeakVelTop) ;
GoVelTable = ResultsTable(GoVelRows, :) ;
velConditions = unique(GoVelTable.Condition) ;
for k = 1:numel(velConditions)
    cond     = velConditions(k) ;
    idx      = GoVelTable.Condition == cond ;
    vel_vals = GoVelTable.PeakVelTop(idx) ;
    fprintf('  %s: n=%d, 平均=%.1f m/s, SD=%.1f m/s\n', ...
        char(cond), sum(idx), mean(vel_vals), std(vel_vals)) ;
end

% -----------------------------------------------------------------------
% グラフ表示
% -----------------------------------------------------------------------
figure(1) ; clf

% ---- 条件別 最大バット先端速度 箱ひげ図（全試行）----
% NoGo 試行もあえて含める。NoGo の PeakVelTop がスイングより桁で低いことを
% 目で確かめられ、01 論点2 の「スイング有無判定」の根拠になるため。
allConditions = unique(ResultsTable.Condition) ;
cond_vel  = [] ;
grp_idx2  = [] ;
lbl_cell2 = {} ;
for k = 1:numel(allConditions)
    cond = allConditions(k) ;
    idx  = ResultsTable.Condition == cond ;
    vel  = ResultsTable.PeakVelTop(idx) ;
    cond_vel  = [cond_vel ; vel] ;                       %#ok<AGROW>
    grp_idx2  = [grp_idx2 ; repmat(k, sum(idx), 1)] ;    %#ok<AGROW>
    lbl_cell2{k} = char(cond) ;
end
if ~isempty(cond_vel)
    boxplot(cond_vel, grp_idx2, 'Labels', lbl_cell2) ;
end
ylabel('最大バット先端速度 (m/s)') ;
title('条件別 スイングスピード（全試行）') ;
grid on

sgtitle(sprintf('マルチ試行分析結果 Subject %02d', iSubject)) ;

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
