% x4s_analyze_single_trial.m
%
% 目的:
%   x3_DataChecked/ のデータを読み込み、全被験者・全条件・全試行に対して
%   m3_analyze_single_trial() を実行し、結果を x4_SingleTrialAnalysisResults/ に保存する。
%   ワークフロー Step 4 に対応。

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

    % 保存
    resultFilePath = sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject) ;
    save(resultFilePath, 'SingleTrialResultArray') ;
    fprintf('  → 保存完了: %s.mat\n\n', resultFilePath) ;

    clear DataArray SingleTrialResultArray

end % iSubject

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
Result.FxFilt          = [] ;
Result.BWTail          = NaN ;   % ★追加（BWBase の直前。m3 と並び順を揃える）
Result.BWBase          = NaN ;
Result.PeakFz1         = NaN ;
Result.PeakFz2         = NaN ;
Result.Fz1Filt         = [] ;   % ★追加
Result.Fz2Filt         = [] ;   % ★追加
end
