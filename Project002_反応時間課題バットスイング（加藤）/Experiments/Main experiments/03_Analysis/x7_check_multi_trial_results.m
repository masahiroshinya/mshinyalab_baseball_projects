% x7_check_multi_trial_results.m
%
% 目的:
%   x6 で保存したマルチ試行結果テーブルを読み込み、
%   集計サマリーとグラフで結果を目視確認する。
%   確認が終わったら y/n で x7_MultiTrialAnalysisResultsChecked/ に保存する。
%   ワークフロー Step 7 に対応。
%
% 備考:
%   RT は Nasu 方式（手部速度）と床反力方式（後ろ足 Fz1）の2方式を並記する。

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
% RT は現在すべて NaN（角速度検出を廃止し、新しい検出信号は 00 で検討中）。
% RT は2方式を並記する。x4 で全試行について算出しているため、
% 「RT が NaN ＝ 抑制成功」という数え方はもう成立しない。
% NoGo の抑制判定はこのスクリプトでは行わない（別途実施）。
RTMethodArray = {'RTHand_ms', 'RTForce_ms'} ;
RTMethodLabel = {'Nasu 方式（手部速度）', '床反力方式（後ろ足 Fz1）'} ;

GoTable      = ResultsTable(ResultsTable.CueText == "Go", :) ;
goConditions = unique(GoTable.Condition) ;

for m = 1:numel(RTMethodArray)
    col = RTMethodArray{m} ;
    fprintf('\n--- 条件別 RT サマリー：%s（Go 試行）---\n', RTMethodLabel{m}) ;
    for k = 1:numel(goConditions)
        cond = goConditions(k) ;
        rt   = GoTable.(col)(GoTable.Condition == cond) ;
        rt   = rt(~isnan(rt)) ;
        fprintf('  %-8s: n=%2d, 平均=%6.1f ms, SD=%5.1f ms\n', ...
            char(cond), numel(rt), mean(rt), std(rt)) ;
    end
end

% 2方式の差。床反力が先行するはずなので、正の値で揃うのが期待される挙動。
fprintf('\n--- 2方式の差（RTHand - RTForce、Go 試行）---\n') ;
for k = 1:numel(goConditions)
    cond = goConditions(k) ;
    d = GoTable.RTDiff_ms(GoTable.Condition == cond) ;
    d = d(~isnan(d)) ;
    fprintf('  %-8s: n=%2d, 平均=%+6.1f ms, SD=%5.1f ms, 正の割合=%d/%d\n', ...
        char(cond), numel(d), mean(d), std(d), sum(d>0), numel(d)) ;
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
