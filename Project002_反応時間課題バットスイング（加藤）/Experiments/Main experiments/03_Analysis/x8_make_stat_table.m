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

subjects       = 1:5 ;
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

    % ---- 被験者の体重を推定する（記録末端 0.5 s、外れ値除去、中央値）----
    %  ★ 分母をキュー前の BWBase から末端推定に変えた（技術説明 §8 の最優先方針、§10）。
    %    S03 は踏み込み足をプレート外に置いて構えるため BWBase が体重を 24% 過小に
    %    見積もり、%BW が 24% 過大になっていた。末端は全被験者で両足がプレート上に
    %    あるので構えの違いに依存しない。他4名は BWBase と ±2% 以内で一致する。
    E = T.BWTail_N(~isnan(T.BWTail_N)) ;
    if isempty(E)
        error('S%02d: BWTail_N が全試行 NaN です。m3 から実行し直してください。', iSubject) ;
    end
    bwEst = median( E(E > Prm.Excl.BWOutlierRatio * median(E)) ) ;

    fprintf('  推定体重: %.1f N（約 %.1f kg、末端 %d 試行から）\n', ...
        bwEst, bwEst/9.81, numel(E)) ;

    % ---- 除外基準②：床反力が正常に計測できていない試行 ----
    %  ★ 「床反力に欠損がある」だけで判定する（§10.8 の実行結果で確定）。
    %    末端荷重が推定体重から外れる試行を落とす案は棄却した。それは
    %    「記録終端までに被験者がプレートから降りた」ことしか意味せず、
    %    スイング時の計測が壊れている証拠にならない。実測でも、落とす試行の
    %    PeakFz2 分布は残す試行とほぼ同一（中央値 130.1 vs 135.9 %BW）で、
    %    正常データを 247 試行中 53 本（21%）捨てていた。
    %    BWest は分母としてのみ使う。
    T.IsBadGRF = isnan(T.BWTail_N) | isnan(T.PeakFz1_N) | isnan(T.PeakFz2_N) ;

    for k = find(T.IsBadGRF)'
        fprintf('  除外（床反力）: %-8s 行%2d  BWTail = %.1f N\n', ...
            T.Condition(k), T.Trial(k), T.BWTail_N(k)) ;
    end
    for k = find(T.IsBadTop)'
        fprintf('  除外（top）    : %-8s 行%2d  窓内の欠損 %g フレーム（記録全体の最長連続 %g）\n', ...
            T.Condition(k), T.Trial(k), T.NNanInWinTop(k), T.MaxNanRunTop(k)) ;
    end

    % ---- 体重正規化（分母は被験者ごとの推定体重）----
    T.BWest_N    = repmat(bwEst, height(T), 1) ;
    T.PeakFz1_BW = T.PeakFz1_N ./ bwEst ;
    T.PeakFz2_BW = T.PeakFz2_N ./ bwEst ;

    % ---- 除外の適用（行は残し、該当する指標だけ NaN にする）----
    %  ★ 技術説明 §3.9 の教訓。top の不良は top 由来の指標だけを落とし、
    %    床反力の不良は床反力の指標だけを落とす。片方の失敗で他方を巻き添えに
    %    しない。除外基準はこの2つだけ（§10.1）。
    T.PeakFz1_BW(T.IsBadGRF)  = NaN ;
    T.PeakFz2_BW(T.IsBadGRF)  = NaN ;
    T.PeakVelTop( T.IsBadTop) = NaN ;
    T.PeakVelTopX(T.IsBadTop) = NaN ;

    % ---- 集計対象フラグ（Methods 2-4「集計対象の試行」）----
    %  NoGo・Stop はスイングの抑制自体が課題なので比較対象にしない。
    %  これはデータ品質の除外ではなく課題設計上の選別なので、上の2基準とは別軸。
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
