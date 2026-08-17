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
subjects           = 1 ;
ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ;
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
    load(filePath)

    nTrial = size(SingleTrialResultArray, 1) ;

    ResultsTable = table() ;   % ← ループ内に移動（被験者ごとにリセット）

    for iCondition = 1:nCondition
        condName = ConditionNameArray{iCondition} ;

        nAdded = 0 ;

        for iTrial = 1:nTrial
            Result = SingleTrialResultArray(iTrial, iCondition) ;

            % 解析結果が空の要素（欠測試行・エラー試行）はテーブルに入れない
            if isempty(Result.NetVelTop)
                continue
            end

            nAdded = nAdded + 1 ;
                        % RT は2方式を並記する。どの試行を反応時間として報告するかは
            % CueText 列で選別できるようにし、ここでは全試行を残す。
            newRow = table( ...
            iSubject, string(condName), iTrial, string(Result.CueText), ...
            Result.TCueMarker, ...
            Result.SwingOnsetHand,  Result.RTHand, ...
            Result.SwingOnsetForce, Result.RTForce, ...
            Result.RTHand - Result.RTForce, ...
            Result.PeakVelHandX, ...
            Result.PeakVelTop, Result.TPeakVelTop, ...
            Result.PeakVelTopX, Result.TPeakVelTopX, Result.VelTopXAtPeak, ...
            'VariableNames', { ...
            'Subject', 'Condition', 'Trial', 'CueText', ...
            'TCueMarker', ...
            'SwingOnsetHand',  'RTHand_ms', ...
            'SwingOnsetForce', 'RTForce_ms', ...
            'RTDiff_ms', ...
            'PeakVelHandX', ...
            'PeakVelTop', 'TPeakVelTop', ...
            'PeakVelTopX', 'TPeakVelTopX', 'VelTopXAtPeak' ...
            }) ;
            ResultsTable = [ResultsTable ; newRow] ; %#ok<AGROW>
        end % iTrial

        fprintf('  条件: %s  (%d 試行) → テーブルに追記しました\n', condName, nAdded) ;

    end % iCondition

    % ← 保存処理をループ内に移動（被験者ごとに個別保存）
    savePath = sprintf('x6_MultiTrialAnalysisResults/MultiTrialResults%02d', iSubject) ;
    save(savePath, 'ResultsTable') ;
    fprintf('\n保存完了: %s.mat\n', savePath) ;
    fprintf('  → 総行数（試行数）: %d\n', height(ResultsTable)) ;

    clear SingleTrialResultArray

end % iSubject

fprintf('\n=== 処理完了 ===\n') ;  % ← ループ外に残す
