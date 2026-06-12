% x6_analyze_multi_trial.m
%
% 目的:
%   x5_SingleTrialAnalysisResultsChecked/ の確認済みシングル試行結果を
%   全被験者・全条件について読み込み、MATLAB テーブル形式に変換して
%   x6_MultiTrialAnalysisResults/ に保存する。
%   ワークフロー Step 6 に対応。

clear
close all
clc

% -----------------------------------------------------------------------
% 設定
% -----------------------------------------------------------------------
subjects           = [1] ;
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition         = length(ConditionNameArray) ;

% -----------------------------------------------------------------------
% 全試行分の結果を格納するテーブル（初期化）
% -----------------------------------------------------------------------
ResultsTable = table() ;

% -----------------------------------------------------------------------
% 被験者ループ
% -----------------------------------------------------------------------
for iSubject = subjects

    fprintf('=== Subject %02d ===\n', iSubject) ;

    filePath = sprintf('x5_SingleTrialAnalysisResultsChecked/SingleTrialAnalysisResults%02d', iSubject) ;
    if ~exist([filePath '.mat'], 'file')
        fprintf('  ファイルが見つかりません。スキップします。\n') ;
        continue
    end
    load(filePath)  % → SingleTrialResultArray が読み込まれる

    nTrial = size(SingleTrialResultArray, 1) ;

    % ---------------------------------------------------------------
    % 条件ループ
    % ---------------------------------------------------------------
    for iCondition = 1:nCondition
        condName = ConditionNameArray{iCondition} ;

        % -----------------------------------------------------------
        % 試行ループ：1 試行 = テーブルの 1 行
        % -----------------------------------------------------------
        for iTrial = 1:nTrial

            Result = SingleTrialResultArray(iTrial, iCondition) ;

            newRow = table( ...
                iSubject,               ...
                string(condName),       ...
                iTrial,                 ...
                string(Result.CueText), ...
                Result.TCueMarker,      ...
                Result.SwingOnset,      ...
                Result.RT,              ...
                Result.PeakOmegaDeg,    ...
                'VariableNames', {      ...
                'Subject', 'Condition', 'Trial', ...
                'CueText',                       ...
                'TCueMarker', 'SwingOnset',      ...
                'RT_ms', 'PeakOmegaDeg'          ...
                }) ;

            ResultsTable = [ResultsTable ; newRow] ; %#ok<AGROW>

        end % iTrial

        fprintf('  条件: %s  (%d 試行) → テーブルに追記しました\n', condName, nTrial) ;

    end % iCondition

    clear SingleTrialResultArray

end % iSubject

% -----------------------------------------------------------------------
% 結果の保存
% -----------------------------------------------------------------------
savePath = sprintf('x6_MultiTrialAnalysisResults/MultiTrialResults%02d', iSubject) ;
save(savePath, 'ResultsTable') ;
fprintf('\n保存完了: %s.mat\n', savePath) ;
fprintf('  → 総行数（試行数）: %d\n', height(ResultsTable)) ;
fprintf('\n=== 処理完了 ===\n') ;
