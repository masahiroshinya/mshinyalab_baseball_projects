% s_compare_exclusion.m
%
% 目的:
%   目視で記録した除外メモ（exclusion_memo.csv）と、コード上の除外基準
%   （x8 の IsBadTop / IsBadGRF）を試行ごとに突き合わせる。
%
% 前提:
%   x4 まで実行済みであること。
%
% 出力:
%   コマンドウィンドウに不一致・一致の一覧を表示し、
%   全試行の比較表を exclusion_compare.csv に保存する。
%
% 備考:
%   x1〜x9 の解析ワークフローには含まれない診断用スクリプト。
%   コード側の判定は x8 と同じ式で x4 の結果から直接求める（x6〜x8 の実行は不要）。
%   メモの Target が all の行は、top と Fz の両方の除外として扱う。

clear
clc

subjects           = 1:10 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
nCondition         = length(ConditionNameArray) ;

% -----------------------------------------------------------------------
% 除外メモの読み込み
% -----------------------------------------------------------------------
memo = readtable('exclusion_memo.csv', 'TextType', 'string', ...
    'Delimiter', ',', 'Encoding', 'UTF-8') ;
% 空のメモでも比較できるよう文字列型にそろえる
memo.Condition = strtrim(string(memo.Condition)) ;
memo.Target    = lower(strtrim(string(memo.Target))) ;
memo.Reason    = string(memo.Reason) ;
isMatched      = false(height(memo), 1) ;   % 実在する試行に対応したか

% -----------------------------------------------------------------------
% 試行ごとにコード判定とメモを突き合わせる
% -----------------------------------------------------------------------
C = table() ;

for iSubject = subjects

    f = sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d.mat', iSubject) ;
    if ~exist(f, 'file')
        fprintf('S%02d: x4 の結果が見つかりません。スキップします。\n', iSubject) ;
        continue
    end
    S = load(f) ;
    A = S.SingleTrialResultArray ;

    for iCondition = 1:nCondition
        condName = string(ConditionNameArray{iCondition}) ;

        for iTrial = 1:size(A, 1)

            R = A(iTrial, iCondition) ;
            if R.IsNoData, continue, end   % 存在しない試行（埋め要素）

            % コード側（x8 と同じ判定）
            codeTop = R.IsBadTop ;
            codeFz  = isnan(R.BWTail) || isnan(R.PeakFz1) || isnan(R.PeakFz2) ;

            % メモ側
            m   = memo.Subject == iSubject & memo.Condition == condName & memo.Trial == iTrial ;
            tgt = memo.Target(m) ;
            isMatched(m) = true ;
            memoTop = any(ismember(tgt, ["top", "all"])) ;
            memoFz  = any(ismember(tgt, ["fz",  "all"])) ;

            row = table(iSubject, condName, iTrial, string(R.CueText), ...
                codeTop, memoTop, judge(codeTop, memoTop), ...
                codeFz,  memoFz,  judge(codeFz,  memoFz), ...
                strjoin(memo.Reason(m), ' / '), ...
                'VariableNames', {'Subject', 'Condition', 'Trial', 'CueText', ...
                'CodeTop', 'MemoTop', 'JudgeTop', ...
                'CodeFz',  'MemoFz',  'JudgeFz', 'MemoReason'}) ;
            C = [C ; row] ; %#ok<AGROW>
        end
    end
end

% -----------------------------------------------------------------------
% 結果の表示
% -----------------------------------------------------------------------
printJudge(C, 'JudgeTop', 'top') ;
printJudge(C, 'JudgeFz',  'Fz') ;

% 実在する試行に対応しなかったメモ（番号の書き間違いなど）
if any(~isMatched)
    fprintf('\n--- 対応する試行が見つからないメモ（書き間違いの可能性）---\n') ;
    disp(memo(~isMatched, :)) ;
end

writetable(C, 'exclusion_compare.csv', 'Encoding', 'UTF-8') ;
fprintf('\n比較表を保存しました: exclusion_compare.csv（%d 試行）\n', height(C)) ;


% -----------------------------------------------------------------------
% ローカル関数：判定の分類
% -----------------------------------------------------------------------
function s = judge(code, memo)
if code && memo
    s = "一致" ;
elseif memo
    s = "メモのみ" ;
elseif code
    s = "コードのみ" ;
else
    s = "" ;
end
end

% -----------------------------------------------------------------------
% ローカル関数：分類ごとの一覧を表示
% -----------------------------------------------------------------------
function printJudge(C, col, label)
fprintf('\n===== %s =====\n', label) ;
for s = ["メモのみ", "コードのみ", "一致"]
    idx = find(C.(col) == s) ;
    fprintf('\n[%s] %d 試行\n', s, numel(idx)) ;
    for k = idx'
        fprintf('  S%02d %-7s Trial %2d [%-4s] %s\n', ...
            C.Subject(k), C.Condition(k), C.Trial(k), C.CueText(k), C.MemoReason(k)) ;
    end
end
end
