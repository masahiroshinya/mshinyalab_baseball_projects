% x4s_analyze_single_trial.m
%
% 目的:
%   x3_DataChecked/ のデータを読み込み、全被験者・全条件・全試行に対して
%   m3_analyze_single_trial() を実行し、結果を x4_SingleTrialAnalysisResults/ に保存する。
%   ワークフロー Step 4 に対応。
%
% 出力:
%   x4_SingleTrialAnalysisResults/SingleTrialAnalysisResultsNN.mat
%   x4_SingleTrialAnalysisResults/code_exclusion_list.csv
%     コードの判定で解析から外す対象の一覧（Go 試行のみ）。x5 で波形と見比べて Mark 列に印を付ける。
%       Mark = k       … コードは除外するが、目視で除外しないと判断した（Note に理由）
%       Mark = exclude … コードは除外しないが、目視で除外すると判断した。一覧にない試行なので
%                        行を書き足す（Reason は空欄でよい。Note に理由）
%     x8 はこの印に従って除外を取り消し・追加する。
%     x4 を実行し直しても、前回の CSV の Mark・Note は引き継ぐ（技術説明 §21）。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
subjects           = 1:10 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
nCondition         = length(ConditionNameArray) ;

Prm = parameters ;   % 欠測試行（NoData）の判別に使う

CodeExclList = table() ;   % コードの判定で解析から外す対象（全被験者分）

% -----------------------------------------------------------------------
% 被験者ループ
% -----------------------------------------------------------------------
for iSubject = subjects

    fprintf('=== Subject %02d ===\n', iSubject) ;

    dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
    load(dataFilePath)

    nTrial = size(DataArray, 1) ;

    % 結果格納用の配列（事前確保）
    clear SingleTrialResultArray


    % ---------------------------------------------------------------
    % 条件ループ
    % ---------------------------------------------------------------
    for iCondition = 1:nCondition
        condName = ConditionNameArray{iCondition} ;
        fprintf('  条件: %s\n', condName) ;

        % -----------------------------------------------------------
        % 試行ループ
        % -----------------------------------------------------------
        for iTrial = 1:nTrial

            Data = DataArray(iTrial, iCondition) ;

            % 条件ごとの試行数の差を埋めた要素（実データなし）はスキップする
            if isequal(Data.ErrorCode, Prm.ErrorCode.NoData)
                SingleTrialResultArray(iTrial, iCondition) = makeEmptyResult() ;
                fprintf('    Trial %2d: データなし → スキップ\n', iTrial) ;
                continue
            end

            try
                Result = m3_analyze_single_trial(Data) ;
            catch ME
                % ★変更：例外で試行を捨てない。従来はここで makeEmptyResult() に
                %   差し替えていたため、1指標の計算が失敗しただけで top も床反力も
                %   失われていた（技術説明 §3.9）。例外は除外基準ではなく、
                %   直すべきバグとして扱う（§10.3）。
                fprintf(2, '    Trial %2d: 予期しないエラー → 中断します\n', iTrial) ;
                rethrow(ME) ;
            end

            SingleTrialResultArray(iTrial, iCondition) = Result ;

            fprintf('    Trial %2d [%s]: RTForce = %.1f ms\n', ...
                iTrial, Result.CueText, Result.RTForce) ;


        end % iTrial
    end % iCondition

    % ---------------------------------------------------------------
    % Result.RT / SwingOnset は床反力方式の別名とする（下流の互換のため）
    % ---------------------------------------------------------------
    [SingleTrialResultArray.SwingOnset] = deal(NaN) ;
    [SingleTrialResultArray.RT]         = deal(NaN) ;
    for k = 1:numel(SingleTrialResultArray)
        SingleTrialResultArray(k).SwingOnset = SingleTrialResultArray(k).SwingOnsetForce ;
        SingleTrialResultArray(k).RT         = SingleTrialResultArray(k).RTForce ;
    end

    % コードの判定で解析から外す対象を一覧に加える（x5 で目視と見比べる）
    CodeExclList = [CodeExclList ; ...
        listCodeExclusion(SingleTrialResultArray, iSubject, ConditionNameArray, Prm)] ; %#ok<AGROW>

    % 保存
    resultFilePath = sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject) ;
    save(resultFilePath, 'SingleTrialResultArray') ;
    fprintf('  → 保存完了: %s.mat\n\n', resultFilePath) ;

    clear DataArray SingleTrialResultArray

end % iSubject

codeListPath = 'x4_SingleTrialAnalysisResults/code_exclusion_list.csv' ;
CodeExclList = carryOverMark(CodeExclList, codeListPath, subjects) ;
writetable(CodeExclList, codeListPath, 'Encoding', 'UTF-8') ;
fprintf('解析から外す対象の一覧を保存しました: code_exclusion_list.csv（%d 行。k %d 行、exclude %d 行）\n', ...
    height(CodeExclList), sum(CodeExclList.Mark == "k"), sum(CodeExclList.Mark == "exclude")) ;

fprintf('=== 全被験者の処理が完了しました ===\n') ;


% -----------------------------------------------------------------------
% ローカル関数：エラー時の空の Result
%   m3 の出力とフィールド名・並び順を完全に一致させること。
%   一致していないと構造体配列への代入が
%   「異なる構造体での添字による代入です」で落ちる（技術説明 §3.5）。
% -----------------------------------------------------------------------
function Result = makeEmptyResult()
Result.IsNoData        = true ;   % ★追加：存在しない試行（NoData の埋め要素）
Result.IsBadTop        = true ;   % ★追加
Result.MaxNanRunTop    = Inf ;    % ★追加
Result.NNanInWinTop    = NaN ;    % ★追加（m3 と並び順を揃える）
Result.Fz1Min         = NaN ;    % ★追加（2026-09-30、m3 と並び順を揃える）
Result.Fz2Min         = NaN ;    % ★追加
Result.NetVelTop       = [] ;
Result.VelTopX         = [] ;
Result.PeakVelTop      = NaN ;
Result.TPeakVelTop     = NaN ;
Result.PeakVelTopX     = NaN ;
Result.TPeakVelTopX    = NaN ;
Result.VelTopXAtPeak   = NaN ;
Result.CueCode         = NaN ;
Result.CueText         = '' ;
Result.TCueMarker      = NaN ;
Result.FxBase          = NaN ;   % ★変更：Fz1BaseMean から改名（Fx 方式へ移行）
Result.FxThr           = NaN ;   % ★変更：Fz1BaseSD から改名
Result.SwingOnsetForce = NaN ;
Result.RTForce         = NaN ;
Result.MTForce         = NaN ;
Result.FxFilt          = [] ;
Result.BWTail          = NaN ;   % ★追加（BWBase の直前。m3 と並び順を揃える）
Result.BWBase          = NaN ;
Result.PeakFz1         = NaN ;
Result.PeakFz2         = NaN ;
Result.Fz1Filt         = [] ;   % ★追加
Result.Fz2Filt         = [] ;   % ★追加
end


% -----------------------------------------------------------------------
% ローカル関数：コードの判定で解析から外す対象を一覧にする
%   判定は x8 と同じ（技術説明 §19）。Go 試行だけを対象にする。
%   書式は exclusion_memo.csv にそろえる（1行 = 1試行・1つの対象）。
%   ・onset 未検出                → all（ほかの判定は書かない）
%   ・RT < Prm.RT.FloorMs          → RT（x8 は除外しない。目視と見比べるための候補）
%   ・解析窓内に top の欠損        → top
%   ・床反力の欠損、または Fz のゼロ点ずれ（記録全体の Fz1 / Fz2 の最小値 < −50 N）→ Fz
% -----------------------------------------------------------------------
function T = listCodeExclusion(A, iSubject, ConditionNameArray, Prm)
Subject   = zeros(0, 1) ;
Condition = strings(0, 1) ;
Trial     = zeros(0, 1) ;
Target    = strings(0, 1) ;
Reason    = strings(0, 1) ;

for iCondition = 1:size(A, 2)
    for iTrial = 1:size(A, 1)

        R = A(iTrial, iCondition) ;
        if R.IsNoData || ~strcmp(R.CueText, 'Go'), continue, end

        tgt = strings(0, 1) ;
        rsn = strings(0, 1) ;
        if isnan(R.RTForce)
            tgt(end+1, 1) = "all" ;
            rsn(end+1, 1) = "onset 未検出（RTForce = NaN）" ;
        else
            if R.RTForce < Prm.RT.FloorMs
                tgt(end+1, 1) = "RT" ;
                rsn(end+1, 1) = sprintf("RT が生理的下限（%d ms）を下回る（%.0f ms）", ...
                    Prm.RT.FloorMs, R.RTForce) ;
            end
            if R.IsBadTop
                tgt(end+1, 1) = "top" ;
                rsn(end+1, 1) = sprintf("解析窓内に top の欠損（%g フレーム）", R.NNanInWinTop) ;
            end
            if isnan(R.BWTail) || isnan(R.PeakFz1) || isnan(R.PeakFz2)
                tgt(end+1, 1) = "Fz" ;
                rsn(end+1, 1) = "床反力の欠損" ;
            elseif R.Fz1Min < -Prm.RT.FootContactN || R.Fz2Min < -Prm.RT.FootContactN
                tgt(end+1, 1) = "Fz" ;
                rsn(end+1, 1) = sprintf("Fz のゼロ点ずれ（最小値 Fz1 %.0f N / Fz2 %.0f N）", ...
                    R.Fz1Min, R.Fz2Min) ;
            end
        end

        n = numel(tgt) ;
        Subject   = [Subject   ; repmat(iSubject, n, 1)] ;                            %#ok<AGROW>
        Condition = [Condition ; repmat(string(ConditionNameArray{iCondition}), n, 1)] ; %#ok<AGROW>
        Trial     = [Trial     ; repmat(iTrial, n, 1)] ;                              %#ok<AGROW>
        Target    = [Target    ; tgt] ;                                               %#ok<AGROW>
        Reason    = [Reason    ; rsn] ;                                               %#ok<AGROW>
    end
end

T = table(Subject, Condition, Trial, Target, Reason) ;
end


% -----------------------------------------------------------------------
% ローカル関数：前回の一覧から Mark・Note を引き継ぐ
%   行の照合は Subject・Condition・Trial・Target。
%   ・k       … 今回の一覧に同じ行があれば引き継ぐ。なければ（コードが除外しなくなった）
%               引き継がず、コマンドウィンドウに知らせる
%   ・exclude … ユーザーが書き足した行なので、今回の判定に関係なく残す。
%               今回の一覧に同じ行があれば、その行に印を移す
%   ・今回処理しなかった被験者の行は、前回の一覧のまま残す
% -----------------------------------------------------------------------
function New = carryOverMark(New, filePath, subjects)
New.Mark = strings(height(New), 1) ;
New.Note = strings(height(New), 1) ;
if ~exist(filePath, 'file'), return, end

Old = readJudgeList(filePath) ;
Added = New([], :) ;   % 今回の一覧にない exclude の行

for k = find(Old.Mark ~= "" & ismember(Old.Subject, subjects))'
    m = New.Subject == Old.Subject(k) & New.Condition == Old.Condition(k) ...
      & New.Trial   == Old.Trial(k)   & New.Target    == Old.Target(k) ;
    if any(m)
        New.Mark(m) = Old.Mark(k) ;
        New.Note(m) = Old.Note(k) ;
    elseif Old.Mark(k) == "exclude"
        Added = [Added ; Old(k, New.Properties.VariableNames)] ; %#ok<AGROW>
    else
        fprintf(2, '  （注意）%s を付けていた S%02d %s Trial %d [%s] は、今回の判定で除外されなくなったので一覧から消えます\n', ...
            Old.Mark(k), Old.Subject(k), Old.Condition(k), Old.Trial(k), Old.Target(k)) ;
    end
end

% 今回処理しなかった被験者の行は前回のまま残す
New = [Old(~ismember(Old.Subject, subjects), New.Properties.VariableNames) ; New ; Added] ;
New = sortrows(New, {'Subject'}) ;   % 同じ被験者の中では今回の一覧の順（書き足した行は末尾）
end

% -----------------------------------------------------------------------
% ローカル関数：code_exclusion_list.csv を読み、型をそろえる
%   Excel で編集すると、空欄だけの列が数値として読まれることがあるので、文字列にそろえる。
% -----------------------------------------------------------------------
function T = readJudgeList(filePath)
T = readtable(filePath, 'TextType', 'string', 'Delimiter', ',', 'Encoding', 'UTF-8') ;
for v = ["Condition", "Target", "Reason", "Mark", "Note"]
    if ~ismember(v, T.Properties.VariableNames) || ~isstring(T.(v))
        T.(v) = strings(height(T), 1) ;   % 列がない（古い一覧）か、全部空欄
    end
    T.(v)(ismissing(T.(v))) = "" ;
    T.(v) = strtrim(T.(v)) ;
end
T.Mark = lower(T.Mark) ;
T = T(:, {'Subject', 'Condition', 'Trial', 'Target', 'Reason', 'Mark', 'Note'}) ;
end
