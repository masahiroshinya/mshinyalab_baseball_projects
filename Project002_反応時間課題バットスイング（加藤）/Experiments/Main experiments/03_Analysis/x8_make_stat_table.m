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

subjects       = 1:10 ;
ConditionOrder = {'free', 'simple', 'gonogo', 'gostop'} ;
Prm            = parameters ;

% 代表値を算出する従属変数（Methods 2-5 の表に対応）
DVNameArray = {'RTForce_ms', 'PeakVelTop', 'PeakVelTopX', ...
               'PeakFz1_BW', 'PeakFz2_BW'} ;

% x4 が書き出した「解析から外す対象」の一覧と、目視の判断（Mark 列、技術説明 §21）。
%   k       … コードの除外を取り消す
%   exclude … 目視で除外を追加する
codeListPath = 'x4_SingleTrialAnalysisResults/code_exclusion_list.csv' ;
if ~exist(codeListPath, 'file')
    error('%s が見つかりません。x4 を実行してください。', codeListPath) ;
end
CodeList = readtable(codeListPath, 'TextType', 'string', 'Delimiter', ',', 'Encoding', 'UTF-8') ;
CodeList.Condition = strtrim(string(CodeList.Condition)) ;
CodeList.Target    = strtrim(string(CodeList.Target)) ;
if ~ismember('Mark', CodeList.Properties.VariableNames)
    error('%s に Mark 列がありません。x4 を実行し直してください。', codeListPath) ;
end
if ~isstring(CodeList.Mark), CodeList.Mark = strings(height(CodeList), 1) ; end   % 全部空欄
CodeList.Mark(ismissing(CodeList.Mark)) = "" ;
CodeList.Mark = lower(strtrim(CodeList.Mark)) ;

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
    %  ★追加（2026-09-30、§18）：Fz のゼロ点ずれ。記録全体の Fz1 / Fz2 の最小値が
    %    −50 N（-Prm.RT.FootContactN）を下回る試行は、プレートのゼロ点がずれているので
    %    床反力の指標だけを落とす。RT は接地・onset とも相対値で判定しているので残す。
    T.IsFzOffset = T.Fz1Min_N < -Prm.RT.FootContactN | T.Fz2Min_N < -Prm.RT.FootContactN ;
    T.IsBadGRF   = isnan(T.BWTail_N) | isnan(T.PeakFz1_N) | isnan(T.PeakFz2_N) | T.IsFzOffset ;

    for k = find(T.IsBadGRF)'
        fprintf('  除外（床反力）: %-8s 行%2d  BWTail = %.1f N  最小値 Fz1 %.0f N / Fz2 %.0f N\n', ...
            T.Condition(k), T.Trial(k), T.BWTail_N(k), T.Fz1Min_N(k), T.Fz2Min_N(k)) ;
    end

    % ---- 除外基準③：Fx による onset が検出できなかった Go 試行 ----
    %  RT が定まらない試行はスイング開始を捉えられていないので、
    %  top・床反力の指標も含めて試行ごと解析から外す（2026-09-30 追加）。
    %  ★ §10.3「片方の失敗で他方を巻き添えにしない」の意図的な例外。
    %  NoGo・Stop は抑制に成功すれば onset がないのが正常なので対象外。
    T.IsBadOnset = (T.CueText == "Go") & isnan(T.RTForce_ms) ;

    % ---- 除外基準④：RT が生理的下限を下回る Go 試行（2026-09-30 追加、§21）----
    %  RT だけを落とす。top・床反力は残す。
    T.IsShortRT = (T.CueText == "Go") & T.RTForce_ms < Prm.RT.FloorMs ;

    % ---- 目視の判断（code_exclusion_list.csv の Mark 列）----
    %  k       … 取り消せるのは top（①）と RT（④）だけ。all（③）は §19 のとおり取り消さない。
    %            Fz（②）は値そのものが欠損しているので、取り消しても意味がない。
    %  exclude … top / RT / Fz / all のどれでも付けられる。all は③と同じく試行ごと落とす。
    %  コードの判定（IsBad*）はそのまま残し、目視の判断は Keep* / Excl* 列に分けて持つ。
    T.KeepTop = false(height(T), 1) ;
    T.KeepRT  = false(height(T), 1) ;
    T.ExclTop = false(height(T), 1) ;
    T.ExclRT  = false(height(T), 1) ;
    T.ExclGRF = false(height(T), 1) ;
    M = CodeList(CodeList.Subject == iSubject & CodeList.Mark ~= "", :) ;
    for k = 1:height(M)
        m = T.Condition == M.Condition(k) & T.Trial == M.Trial(k) ;
        if ~any(m)
            fprintf(2, '  （注意）%s Trial %d は存在しません。Mark を無視します\n', M.Condition(k), M.Trial(k)) ;
            continue
        end
        switch lower(M.Mark(k) + "/" + M.Target(k))   % 大文字小文字は区別しない
            case "k/top",     T.KeepTop(m) = true ;
            case "k/rt",      T.KeepRT(m)  = true ;
            case "exclude/top",  T.ExclTop(m) = true ;
            case "exclude/rt",   T.ExclRT(m)  = true ;
            case "exclude/fz",   T.ExclGRF(m) = true ;
            case "exclude/all",  T.ExclTop(m) = true ; T.ExclRT(m) = true ; T.ExclGRF(m) = true ;
            otherwise
                fprintf(2, '  （注意）%s Trial %d の %s に %s は付けられません。無視します\n', ...
                    M.Condition(k), M.Trial(k), M.Target(k), M.Mark(k)) ;
        end
    end

    for k = find(T.IsBadOnset)'
        fprintf('  除外（onset）  : %-8s 行%2d  RTForce = NaN\n', ...
            T.Condition(k), T.Trial(k)) ;
    end
    for k = find(T.IsBadTop & ~T.IsBadOnset)'
        fprintf('  除外（top）    : %-8s 行%2d  窓内の欠損 %g フレーム（記録全体の最長連続 %g）%s\n', ...
            T.Condition(k), T.Trial(k), T.NNanInWinTop(k), T.MaxNanRunTop(k), keepMark(T.KeepTop(k))) ;
    end
    for k = find(T.IsShortRT)'
        fprintf('  除外（RT）     : %-8s 行%2d  RT = %.0f ms%s\n', ...
            T.Condition(k), T.Trial(k), T.RTForce_ms(k), keepMark(T.KeepRT(k))) ;
    end

    % ---- 体重正規化（分母は被験者ごとの推定体重）----
    T.BWest_N    = repmat(bwEst, height(T), 1) ;
    T.PeakFz1_BW = T.PeakFz1_N ./ bwEst ;
    T.PeakFz2_BW = T.PeakFz2_N ./ bwEst ;

    % ---- 除外の適用（行は残し、該当する指標だけ NaN にする）----
    %  ★ 技術説明 §3.9 の教訓。top の不良は top 由来の指標だけを落とし、
    %    床反力の不良は床反力の指標だけを落とす。片方の失敗で他方を巻き添えに
    %    しない。ただし onset 未検出（③）は試行ごと落とす（§19）。
    isOutTop = (T.IsBadTop  & ~T.KeepTop) | T.IsBadOnset | T.ExclTop ;
    isOutGRF =  T.IsBadGRF                | T.IsBadOnset | T.ExclGRF ;
    isOutRT  = (T.IsShortRT & ~T.KeepRT)               | T.ExclRT ;   % onset 未検出の RT はもともと NaN

    exclLabel = ["top", "RT", "Fz"] ;
    for k = find(T.ExclTop | T.ExclRT | T.ExclGRF)'
        fprintf('  除外（目視）   : %-8s 行%2d  %s\n', T.Condition(k), T.Trial(k), ...
            strjoin(exclLabel([T.ExclTop(k), T.ExclRT(k), T.ExclGRF(k)]), '+')) ;
    end

    T.PeakVelTop( isOutTop) = NaN ;
    T.PeakVelTopX(isOutTop) = NaN ;
    T.PeakFz1_BW( isOutGRF) = NaN ;
    T.PeakFz2_BW( isOutGRF) = NaN ;
    T.RTForce_ms( isOutRT)  = NaN ;

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
% JASP 用の横長テーブル（1行1被験者、列 = 指標_条件）
%  JASP の反復測定分散分析は、条件を列で並べた形式でしか要因を組めない。
% -----------------------------------------------------------------------
WideTable = table(unique(SubjectTable.Subject), 'VariableNames', {'Subject'}) ;

for iDV = 1:numel(DVNameArray)
    dv = DVNameArray{iDV} ;
    for iCondition = 1:numel(ConditionOrder)
        condName = ConditionOrder{iCondition} ;
        col = NaN(height(WideTable), 1) ;
        for iRow = 1:height(WideTable)
            m = SubjectTable.Subject   == WideTable.Subject(iRow) ...
                & SubjectTable.Condition == condName ;
            if any(m), col(iRow) = SubjectTable.(dv)(m) ; end
        end
        WideTable.([dv '_' condName]) = col ;
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
writetable(WideTable, 'x8_StatTable/stat_table_subject_wide.csv', 'Encoding', 'UTF-8') ;


% -----------------------------------------------------------------------
% ローカル関数：Mark = k の除外に付ける印
% -----------------------------------------------------------------------
function s = keepMark(isKept)
if isKept
    s = '  → k により戻す' ;
else
    s = '' ;
end
end
