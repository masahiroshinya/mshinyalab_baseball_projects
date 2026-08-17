% x8_make_stat_table.m
%
% 目的:
%   x7_MultiTrialAnalysisResultsChecked/ の確認済みテーブルを全被験者分まとめ、
%   統計処理用の tidy テーブルを作成して x8_StatTable/ に保存する。
%   ワークフロー Step 8 に対応。
%
% 出力:
%   x8_StatTable/StatTable.mat            TrialTable と SubjectTable
%   x8_StatTable/stat_table_trial.csv     1行1試行（除外の妥当性を後から追える）
%   x8_StatTable/stat_table_subject.csv   1行1被験者×条件（R に渡す代表値）

clear
close all
clc

subjects       = 1 ;
ConditionOrder = {'free', 'simple', 'gonogo', 'gostop'} ;
Prm            = parameters ;

% 代表値を算出する従属変数（Methods 2-5 の表に対応）
DVNameArray = {'RTHand_ms', 'RTForce_ms', 'PeakVelTop', 'PeakVelTopX', ...
               'PeakFz1_BW', 'PeakFz2_BW'} ;

TrialTable = table() ;

% -----------------------------------------------------------------------
% 被験者ループ：正規化と不良試行の判定は被験者内で完結させる
% -----------------------------------------------------------------------
for iSubject = subjects

    loadPath = sprintf('x7_MultiTrialAnalysisResultsChecked/MultiTrialResults%02d', iSubject) ;
    if ~exist([loadPath '.mat'], 'file')
        fprintf('S%02d: 確認済みテーブルが見つかりません。スキップします。\n', iSubject) ;
        continue
    end
    load(loadPath)   % → ResultsTable

    T = ResultsTable ;
    fprintf('=== Subject %02d（%d 試行）===\n', iSubject, height(T)) ;

    % ---- ベースライン荷重の妥当性チェック（x7_3 の isBadBW と同じ判定）----
    %  静止時の Fz1+Fz2 は体重にほぼ一致するはず。大きく外れる試行は
    %  プレートに正しく乗っていない計測不良で、正規化すると異常値になる。
    bwRef     = median(T.BWBase_N, 'omitnan') ;
    T.IsBadBW = isnan(T.BWBase_N) | abs(T.BWBase_N - bwRef) > Prm.GRF.BWTolerance * bwRef ;

    fprintf('  体重の代表値: %.1f N（約 %.1f kg）\n', bwRef, bwRef/9.81) ;
    for k = find(T.IsBadBW)'
        fprintf('  除外（ベースライン荷重が異常）: %-8s 行%2d  bw = %.1f N\n', ...
            T.Condition(k), T.Trial(k), T.BWBase_N(k)) ;
    end

    % ---- 体重正規化。不良試行は NaN にして代表値の平均から外す ----
    T.PeakFz1_BW = T.PeakFz1_N ./ T.BWBase_N ;
    T.PeakFz2_BW = T.PeakFz2_N ./ T.BWBase_N ;
    T.PeakFz1_BW(T.IsBadBW) = NaN ;
    T.PeakFz2_BW(T.IsBadBW) = NaN ;

    % ---- 集計対象フラグ（Methods 2-4「集計対象の試行」）----
    %  NoGo・Stop はスイングの抑制自体が課題なので比較対象にしない。
    %  行そのものは残し、フラグで選別できるようにしておく。
    T.IsGo = (T.CueText == "Go") ;

    TrialTable = [TrialTable ; T] ; %#ok<AGROW>

end % iSubject

if isempty(TrialTable)
    error('テーブルが空です。x7 まで実行済みか確認してください。') ;
end

% -----------------------------------------------------------------------
% 被験者×条件の代表値（Methods 2-5 (1)：対象試行すべての平均）
% -----------------------------------------------------------------------
SubjectTable = table() ;

for iSubject = unique(TrialTable.Subject)'
    for iCondition = 1:numel(ConditionOrder)

        condName = ConditionOrder{iCondition} ;
        mask = TrialTable.Subject   == iSubject ...
             & TrialTable.Condition == condName ...
             & TrialTable.IsGo ;

        if ~any(mask), continue, end

        row = table(iSubject, string(condName), sum(mask), ...
            'VariableNames', {'Subject', 'Condition', 'nGoTrial'}) ;

        % 平均は omitnan。何試行が実際に平均に入ったかを n_ 列に残しておく
        for iDV = 1:numel(DVNameArray)
            dv = DVNameArray{iDV} ;
            v  = TrialTable.(dv)(mask) ;
            row.(dv)          = mean(v, 'omitnan') ;
            row.(['n_' dv])   = sum(~isnan(v)) ;
        end

        SubjectTable = [SubjectTable ; row] ; %#ok<AGROW>
    end
end

% -----------------------------------------------------------------------
% 保存
% -----------------------------------------------------------------------
save('x8_StatTable/StatTable', 'TrialTable', 'SubjectTable') ;
writetable(TrialTable,   'x8_StatTable/stat_table_trial.csv',   'Encoding', 'UTF-8') ;
writetable(SubjectTable, 'x8_StatTable/stat_table_subject.csv', 'Encoding', 'UTF-8') ;

fprintf('\n=== 保存完了 ===\n') ;
fprintf('  試行単位:   %d 行\n', height(TrialTable)) ;
fprintf('  被験者単位: %d 行（被験者 %d 名 × 条件）\n', ...
    height(SubjectTable), numel(unique(SubjectTable.Subject))) ;
disp(SubjectTable)
