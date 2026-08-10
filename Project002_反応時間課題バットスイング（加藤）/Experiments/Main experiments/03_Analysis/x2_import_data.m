% x2_import_data.m
%
% 目的:
%   本実験の生データ（04_Data/<計測日>_S<ID>/）を読み込み、クリーニングして
%   x2_Data/Data<ID>.mat に保存する。ワークフロー Step 2 に対応。
%
% 備考:
%   - 生データは 03_Analysis の外（../04_Data/）に置いたまま参照する。
%     x1_RawData/ にコピーする運用に変えたい場合は RawDataRoot を書き換える。
%   - 条件ごとに試行数・ファイル番号が異なる（欠番がある）ため、
%     試行数は決め打ちせず実ファイルから取得する。

clear
close all
clc

ConditionNameArray = {'free', 'simple', 'gonogo', 'gostop'} ; % データに含む条件

subjects = 1 ; % データに含む被験者

% 生データの置き場所（被験者 ID をインデックスとするフォルダ名）
RawDataRoot        = fullfile('..', '04_Data') ;
SubjectFolderArray = {'2026-0810_S01'} ;

% parameters
Prm = parameters ;

for iSubject = subjects
    rawDataFolder = fullfile(RawDataRoot, SubjectFolderArray{iSubject}) ;
    nCondition = length(ConditionNameArray) ; % ConditionNameArrayの要素数（＝条件の数）

    for iCondition = 1:nCondition
        conditionName = ConditionNameArray{iCondition} ;

        % 実在するファイルから試行番号を取得する（欠番があるため決め打ちしない）
        TrialFileList  = dir(fullfile(rawDataFolder, sprintf('S%02d_%s*.mat', iSubject, conditionName))) ;
        TrialNumberArray = nan(1, numel(TrialFileList)) ;
        for iFile = 1:numel(TrialFileList)
            [~, baseName] = fileparts(TrialFileList(iFile).name) ;
            TrialNumberArray(iFile) = str2double(baseName(end-3:end)) ;
        end
        TrialNumberArray = sort(TrialNumberArray) ;

        nTrial = numel(TrialNumberArray) ; % 試行数
        fprintf('S%02d %-7s: %d 試行（ファイル番号 %s）\n', ...
            iSubject, conditionName, nTrial, mat2str(TrialNumberArray)) ;

        for iTrial = 1:nTrial
            trialNumber = TrialNumberArray(iTrial) ; % ファイル名上の試行番号
            fileName = [sprintf('S%02d_', iSubject), conditionName, sprintf('%04d', trialNumber)] ; % sprintf：文字列に格納
            X = load_qualisys_mat(rawDataFolder, fileName) ; % load_qualisys_mat.mから帰ってきたデータをXに格納
            X.SubjectID     = iSubject ;
            X.ConditionCode = iCondition ;
            X.ConditionName = conditionName ;
            X.TrialNumber   = trialNumber ;
            X.ErrorCode     = 0 ;
            X.ErrorText     = '' ;

            % interp nans
            [Markers_interp, HasLongNan] = interp_nan_spline(X.Markers, Prm.MaxNumNans) ;
            X.Markers = Markers_interp ;

            if any(cell2mat(struct2cell(HasLongNan)))
                X.ErrorCode = Prm.ErrorCode.HasLongNan ;
                X.ErrorText = Prm.ErrorText.HasLongNan ;
            end


            if isfield(X, 'Analog')
               rawAnalog = X.Analog.Data ;
               if size(rawAnalog, 1) < size(rawAnalog, 2)
                   rawAnalog = rawAnalog' ;
               end
               analogData = rawAnalog ;
               X.LEDData  = analogData(:,1:2) ;
               X.AnalogFs = X.Analog.Frequency ;
            else
               X.LEDData  = [] ;
               X.AnalogFs = NaN ;
               X.ErrorCode = 99 ;
               X.ErrorText = 'Analog data missing' ;
               fprintf('Warning: Analog なし → %s\n', fileName) ;
            end

            if isfield(X, 'Analog')
               XX = rmfields(X, {'MarkerArray', 'Analog'}) ;
            else
               XX = rmfields(X, {'MarkerArray'}) ;
            end


            DataArray(iTrial, iCondition) = XX ;

            clear XX

        end % iTrial

    end % iCondition

    % 条件ごとに試行数が異なると、DataArray の余った要素は空の構造体になる。
    % 後段のスクリプトで判別できるようにエラーコードを入れておく。
    for iCondition = 1:nCondition
        for iTrial = 1:size(DataArray, 1)
            if isempty(DataArray(iTrial, iCondition).ErrorCode)
                DataArray(iTrial, iCondition).SubjectID     = iSubject ;
                DataArray(iTrial, iCondition).ConditionCode = iCondition ;
                DataArray(iTrial, iCondition).ConditionName = ConditionNameArray{iCondition} ;
                DataArray(iTrial, iCondition).TrialNumber   = NaN ;
                DataArray(iTrial, iCondition).ErrorCode     = Prm.ErrorCode.NoData ;
                DataArray(iTrial, iCondition).ErrorText     = Prm.ErrorText.NoData ;
            end
        end
    end


    dataFilePath = sprintf('x2_Data/Data%02d', iSubject) ;
    save(dataFilePath, 'DataArray')


    fprintf('保存完了 / Saved: %s.mat\n', dataFilePath) ;


    clear DataArray

end % iSubject
