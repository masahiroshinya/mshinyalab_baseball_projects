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
subjects           = [1,2] ;
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition         = length(ConditionNameArray) ;

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

            try
                Result = m3_analyze_single_trial(Data) ;
            catch ME
                fprintf('    Trial %2d: エラー "%s" → スキップ\n', iTrial, ME.message) ;
                Result = makeEmptyResult() ;
            end

            SingleTrialResultArray(iTrial, iCondition) = Result ;

            fprintf('    Trial %2d [%s]: RT = %.1f ms\n', ...
                iTrial, Result.CueText, Result.RT) ;

        end % iTrial
    end % iCondition

    % 保存
    resultFilePath = sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject) ;
    save(resultFilePath, 'SingleTrialResultArray') ;
    fprintf('  → 保存完了: %s.mat\n\n', resultFilePath) ;

    clear DataArray SingleTrialResultArray

end % iSubject

fprintf('=== 全被験者の処理が完了しました ===\n') ;


% -----------------------------------------------------------------------
% ローカル関数：エラー時の空の Result
% -----------------------------------------------------------------------
function Result = makeEmptyResult()
Result.PeakOmegaDeg = NaN ;
Result.CueCode       = NaN ;
Result.CueText       = '' ;
Result.TCueMarker    = NaN ;
Result.SwingOnset    = NaN ;
Result.RT            = NaN ;
end
