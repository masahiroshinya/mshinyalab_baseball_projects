% x7_check_multi_trial_results.m
%
% 目的:
%   x6 で保存したマルチ試行結果テーブルを読み込み、
%   集計サマリーとグラフで結果を目視確認する。
%   確認が終わったら y/n で x7_MultiTrialAnalysisResultsChecked/ に保存する。
%   ワークフロー Step 7 に対応。
%
% 備考:
%   RT は床反力方式（前後方向の合成床反力 Fx）。技術説明 §13。

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
% x4 で全試行について算出しているため、「RT が NaN ＝ 抑制成功」という
% 数え方は成立しない。NoGo の抑制判定はこのスクリプトでは行わない（別途実施）。
GoTable      = ResultsTable(ResultsTable.CueText == "Go", :) ;
goConditions = unique(GoTable.Condition) ;

fprintf('\n--- 条件別 RT サマリー：床反力方式 Fx（Go 試行）---\n') ;
for k = 1:numel(goConditions)
    cond = goConditions(k) ;
    rt   = GoTable.RTForce_ms(GoTable.Condition == cond) ;
    nAll = numel(rt) ;
    rt   = rt(~isnan(rt)) ;
    fprintf('  %-8s: n=%2d / %2d, 平均=%6.1f ms, SD=%5.1f ms\n', ...
        char(cond), numel(rt), nAll, mean(rt), std(rt)) ;
end

% -----------------------------------------------------------------------
% 条件別 速度サマリー（Go 試行）
% -----------------------------------------------------------------------
fprintf('\n--- 条件別 バット先端速度サマリー（Go 試行）---\n') ;
GoVelRows  = ResultsTable.CueText == "Go" & ~isnan(ResultsTable.PeakVelTop) ;
GoVelTable = ResultsTable(GoVelRows, :) ;
velConditions = unique(GoVelTable.Condition) ;
for k = 1:numel(velConditions)
    cond = velConditions(k) ;
    idx  = GoVelTable.Condition == cond ;
    fprintf('  %s (n=%d)\n', char(cond), sum(idx)) ;
    fprintf('      合成速度ピーク  : %.1f ± %.1f m/s\n', ...
        mean(GoVelTable.PeakVelTop(idx)),    std(GoVelTable.PeakVelTop(idx))) ;
    fprintf('      Vx ピーク       : %.1f ± %.1f m/s\n', ...
        mean(GoVelTable.PeakVelTopX(idx)),   std(GoVelTable.PeakVelTopX(idx))) ;
    fprintf('      合成ピーク時のVx: %.1f ± %.1f m/s\n', ...
        mean(GoVelTable.VelTopXAtPeak(idx)), std(GoVelTable.VelTopXAtPeak(idx))) ;
    fprintf('      Vx / |V| の比   : %.3f\n', ...
        mean(GoVelTable.VelTopXAtPeak(idx) ./ GoVelTable.PeakVelTop(idx))) ;
end

% -----------------------------------------------------------------------
% 表の検算（x6 が表を正しく組めたか）
% -----------------------------------------------------------------------
fprintf('\n--- 表の検算 ---\n') ;
fprintf('  総行数: %d（期待値: 条件数 × 試行数）\n', height(ResultsTable)) ;
fprintf('  条件ごとの行数:\n') ;
disp(groupsummary(ResultsTable, 'Condition')) ;
fprintf('  PeakVelTop が NaN の行: %d\n', sum(isnan(ResultsTable.PeakVelTop))) ;
fprintf('  Vx > 合成速度 の行（ありえない）: %d\n', ...
    sum(ResultsTable.VelTopXAtPeak > ResultsTable.PeakVelTop + 1e-9)) ;


% -----------------------------------------------------------------------
% 確認後に保存
% -----------------------------------------------------------------------
answer = input('\n集計と検算を確認しました。x7 に保存しますか？ [y/n]: ', 's') ;
if strcmpi(answer, 'y')
    savePath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject) ;
    save(savePath, 'ResultsTable') ;
    fprintf('保存完了: %s.mat\n', savePath) ;
else
    fprintf('保存をキャンセルしました。\n') ;
end
