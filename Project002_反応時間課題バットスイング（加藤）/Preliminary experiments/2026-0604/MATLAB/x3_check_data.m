% x2_check_data.m
%
% 目的 / Purpose:
%   x2_Data/ に保存された DataArray を読み込み、データの妥当性を確認する。
%   確認済みのデータを x3_DataChecked/ に保存する。
%   ワークフロー Step 3 に対応。
%
%   Load DataArray from x2_Data/, perform data quality checks,
%   and save the verified data to x3_DataChecked/.
%   Corresponds to workflow Step 3.
%
% 出力 / Output:
%   x3_DataChecked/Data<SubjectID>.mat  --- 確認済み DataArray
%                                           Verified DataArray struct array
%
% 備考 / Note:
%   チェック処理のプレースホルダ。実際の確認項目は分析スクリプトの作成に
%   合わせて順次追記する。
%   This is a placeholder. Specific checks will be added incrementally
%   as analysis scripts are developed.

clear
close all
clc

% -----------------------------------------------------------------------
% パラメータ設定 / Parameters
% -----------------------------------------------------------------------

% 処理する被験者番号のリスト / List of subject IDs to process
subjects = [1,2] ;

% 条件名リスト / List of condition names
ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;

% -----------------------------------------------------------------------
% 被験者ループ / Subject loop
% -----------------------------------------------------------------------
for iSubject = subjects

    % x2_Data/ から DataArray を読み込む
    % Load DataArray from x2_Data/
    dataFilePath = sprintf('x2_Data/Data%02d', iSubject) ;
    load(dataFilePath)

    % -------------------------------------------------------------------
    % データチェック処理 / Data quality checks
    % （分析スクリプトの作成に合わせて追記予定 / To be added incrementally）
    % -------------------------------------------------------------------


    % -------------------------------------------------------------------
    % 確認済みデータを x3_DataChecked/ に保存
    % Save verified data to x3_DataChecked/
    % -------------------------------------------------------------------
    checkedDataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
    save(checkedDataFilePath, 'DataArray')

    % 保存完了メッセージ / Print confirmation message
    fprintf('保存完了 / Saved: %s.mat\n', checkedDataFilePath) ;

    % 次の被験者に備えて DataArray をクリア
    % Clear DataArray before the next subject iteration
    clear DataArray

end % iSubject
