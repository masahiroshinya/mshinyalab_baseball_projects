% x1_import_data.m
%
% 目?��? / Purpose:
%   Qualisys で計測した生データ (.mat) ?��? x1_RawData/ から読み込み?��?
%   ?��?析し?��?すい構�??体�??��?��?? DataArray に整形して x2_Data/ に保存する�??
%   ワークフロー Step 2 に対応�??
%
%   Load raw motion capture data (.mat) recorded by Qualisys from x1_RawData/,
%   restructure it into a struct array (DataArray), and save to x2_Data/.
%   Corresponds to workflow Step 2.
%
% 出?��? / Output:
%   x2_Data/Data<SubjectID>.mat  --- DataArray(iTrial, iCondition) 構�??体�??��?��??
%                                    struct array indexed by (trial, condition)
%
% 依存関数 / Dependencies:
%   load_qualisys_mat()  --- Qualisys の .mat ファイルを読み込?��?カスタ?��?関数
%                            Custom function to load a Qualisys .mat file

clear
close all
clc

% -----------------------------------------------------------------------
% パラメータ設?��? / Parameters
% -----------------------------------------------------------------------

% 条件名リスト�?Qualisys ファイル名に使われる文字�??��と?��?致させること??��?
% List of condition names (must match the strings used in Qualisys file names)
%   1: free    --- 自由スイング条件  / Free swing condition
%   2: simple  --- 単純反応条件      / Simple reaction condition
%   3: gonogo  --- Go/No-go 反応条件 / Go/No-go reaction condition
ConditionNameArray = {'free', 'simple', 'gonogo'} ;

% 処?��?する被験�??番号のリスト（�?数?��?定可: ?��? [1, 2, 3]??��?
% List of subject IDs to process (multiple subjects allowed, e.g. [1, 2, 3])
subjects = [1,2] ;

% parameters
Prm = parameters ;

% -----------------------------------------------------------------------
% 被験�??ルー?��? / Subject loop
% -----------------------------------------------------------------------
for iSubject = subjects

    % 生データが�??��納されて?��?るフォル?��???��?x1_RawData/??��?
    % Folder containing the raw Qualisys data files
    rawDataFolder = 'x1_RawData/2026-0604_�\������' ;

    nCondition = length(ConditionNameArray) ;

    % -------------------------------------------------------------------
    % 条件ルー?��? / Condition loop
    % -------------------------------------------------------------------
    for iCondition = 1:nCondition
        conditionName = ConditionNameArray{iCondition} ;

        % ?��?条件の試行数 / Number of trials per condition
        nTrial = 20 ;

        % ---------------------------------------------------------------
        % 試行ルー?��? / Trial loop
        % ---------------------------------------------------------------
        for iTrial = 1:nTrial

            % ファイル名を?��?み立てる（�?: S01_free0001??��?
            % Build the file name (e.g., S01_free0001)
            %   S%02d_ : 被験�??番号?��?2桁ゼロ埋め / subject ID zero-padded to 2 digits
            %   %04d   : 試行番号?��?4桁ゼロ埋め   / trial number zero-padded to 4 digits
            fileName = [sprintf('S%02d_', iSubject), conditionName, sprintf('%04d', iTrial)] ;

            % Qualisys .mat ファイルを読み込?��?
            % Load the Qualisys .mat file
            X = load_qualisys_mat(rawDataFolder, fileName) ;

            % -----------------------------------------------------------
            % メタ?��?報の付�? / Attach metadata
            % 後段の?��?析で構�??体単体から試行情報を参照できるようにするため?��?
            % ?��?フィールドに識別?��?報を追記する�??
            % Embed trial-identifying information so that each struct element
            % is self-contained and readable without external indexing.
            % -----------------------------------------------------------
            X.SubjectID     = iSubject ;    % 被験�??番号          / Subject ID
            X.ConditionCode = iCondition ;  % 条件番号            / Condition index (1=free, 2=simple, 3=gonogo)
            X.ConditionName = conditionName ;% 条件名（文字�??��?��?   / Condition name (string)
            X.TrialNumber   = iTrial ;      % 試行番号            / Trial number
            X.ErrorCode     = 0 ;           % エラーコー?��?        / Error code (0 = no error)
            X.ErrorText     = '' ;          % エラー詳細?��?キス?��?  / Error description (empty if no error)
            
            % interp nans
            [Markers_interp, HasLongNan] = interp_nan_spline(X.Markers, Prm.MaxNumNans) ;
            X.Markers = Markers_interp ;
            
            if any(cell2mat(struct2cell(HasLongNan)))
                X.ErrorCode = Prm.ErrorCode.HasLongNan ;
                X.ErrorText = Prm.ErrorText.HasLongNan ;
            end
                
            
            % -----------------------------------------------------------
            % LED ?��?ータの抽出 / Extract LED data
            % Analog.Data は [チャンネル数 ?��? サンプル数] の行�??��?��??��ため転置し�??
            % [サンプル数 ?��? チャンネル数] に変換してから先�??��2チャンネルを取得する�??
            % Analog.Data is stored as [channels ?��? samples], so transpose it
            % to [samples ?��? channels] before extracting the first two channels.
            %   チャンネル1 / Channel 1: LED1 --- 刺?��?提示タイミングの記録 / Stimulus onset timing
            %   チャンネル2 / Channel 2: LED2 --- 予備チャンネル           / Reserved channel
            % -----------------------------------------------------------
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
               fprintf('Warning: Analog �Ȃ� �� %s\n', fileName) ;
            end

            % -----------------------------------------------------------
            % 不要フィールド�??��削除 / Remove unnecessary fields
            % MarkerArray および Analog は上記で?��?要な?��?ータを抽出済みのため削除し�??
            % 構�??体�??��サイズを削減する�??
            % MarkerArray and Analog have been fully processed above;
            % removing them reduces struct size.
            % -----------------------------------------------------------
            if isfield(X, 'Analog')
               XX = rmfields(X, {'MarkerArray', 'Analog'}) ;
            else
               XX = rmfields(X, {'MarkerArray'}) ;
            end


            % DataArray(試行番号, 条件番号) に格?��?
            % Store into DataArray indexed by (trial, condition)
            DataArray(iTrial, iCondition) = XX ;

            clear XX

        end % iTrial

    end % iCondition

    % -------------------------------------------------------------------
    % DataArray ?��? x2_Data/ に保�? / Save DataArray to x2_Data/
    % ファイル名�? / Example file name: x2_Data/Data01.mat
    % -------------------------------------------------------------------
    dataFilePath = sprintf('x2_Data/Data%02d', iSubject) ;
    save(dataFilePath, 'DataArray')

    % 保存完�?メ?��?セージ / Print confirmation message
    fprintf('保存完�? / Saved: %s.mat\n', dataFilePath) ;

    % 次の被験�??に備えて DataArray をクリア
    % Clear DataArray before the next subject iteration
    clear DataArray

end % iSubject
