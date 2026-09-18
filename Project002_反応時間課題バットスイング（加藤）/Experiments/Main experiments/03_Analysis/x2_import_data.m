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

% 解析対象の被験者 ID。
%   []      → 04_Data にあるフォルダを全て処理する（被験者が増えても書き換え不要）
%   [3]     → S03 だけをやり直す
%   [2 4 5] → 指定した被験者だけ
subjects = [] ;

% 生データの置き場所
RawDataRoot = fullfile('..', '04_Data') ;

% ---- 04_Data 直下の S** フォルダから被験者を自動で拾う ----
FolderList = dir(fullfile(RawDataRoot, 'S*')) ;
FolderList = FolderList([FolderList.isdir]) ;

FoundIDArray   = nan(1, numel(FolderList)) ;
FoundNameArray = cell(1, numel(FolderList)) ;
for iFolder = 1:numel(FolderList)
    FoundIDArray(iFolder)   = str2double(FolderList(iFolder).name(2:end)) ;
    FoundNameArray{iFolder} = FolderList(iFolder).name ;
end

% S の後ろが数字でないフォルダ（S_old など）は対象外にする
isValidFolder  = ~isnan(FoundIDArray) ;
FoundIDArray   = FoundIDArray(isValidFolder) ;
FoundNameArray = FoundNameArray(isValidFolder) ;

[FoundIDArray, sortOrder] = sort(FoundIDArray) ;
FoundNameArray = FoundNameArray(sortOrder) ;

if isempty(FoundIDArray)
    error('x2_import_data:NoSubjectFolder', ...
        '被験者フォルダが見つかりません: %s', RawDataRoot) ;
end

if isempty(subjects)
    subjects = FoundIDArray ;
else
    missingID = setdiff(subjects, FoundIDArray) ;
    if ~isempty(missingID)
        error('x2_import_data:FolderNotFound', ...
            '04_Data に無い被験者が指定されています: %s', mat2str(missingID)) ;
    end
end

fprintf('検出した被験者: %s\n', strjoin(FoundNameArray, ', ')) ;
fprintf('今回の対象    : %s\n\n', mat2str(subjects)) ;


% parameters
Prm = parameters ;

for iSubject = subjects
    % ID からフォルダ名を引く（添字ではなく ID で対応させる）
    rawDataFolder = fullfile(RawDataRoot, FoundNameArray{FoundIDArray == iSubject}) ;
    nCondition = length(ConditionNameArray) ; % ConditionNameArrayの要素数（＝条件の数）

    for iCondition = 1:nCondition
        conditionName = ConditionNameArray{iCondition} ;

        % ---- S06 の命名ミスを読み込み時に補正する ----
        %  S06 は計測時に free と simple のファイル名を取り違えて保存した。
        %  根拠: foreperiod（白LED点灯 → 緑LED点灯）は
        %        free   = 1.5 s 固定（02_Script/demo_5_4_free_main_experiments.m）
        %        simple = 1.2〜1.8 s 変動（CSV プロトコルで試行ごとに指定）
        %        S06 は free*.mat が変動、simple*.mat が 1.5 s 固定で、
        %        S01〜S05 と逆になっていた（2026-09-17 に全60試行で確認）。
        %  ここではディスク上のファイル名だけを読み替え、条件の中身
        %  （ConditionCode / ConditionName）には正しい条件を入れる。
        %  生データ（04_Data/S06/*.mat）には手を加えない。
        fileConditionName = conditionName ;
        if iSubject == 6
            switch conditionName
                case 'free'
                    fileConditionName = 'simple' ;
                case 'simple'
                    fileConditionName = 'free' ;
            end
        end

        % 実在するファイルから試行番号を取得する（欠番があるため決め打ちしない）
        TrialFileList  = dir(fullfile(rawDataFolder, sprintf('S%02d_%s*.mat', iSubject, fileConditionName))) ;
        TrialNumberArray = nan(1, numel(TrialFileList)) ;
        for iFile = 1:numel(TrialFileList)
            [~, baseName] = fileparts(TrialFileList(iFile).name) ;
            TrialNumberArray(iFile) = str2double(baseName(end-3:end)) ;
        end
        TrialNumberArray = sort(TrialNumberArray) ;

        nTrial = numel(TrialNumberArray) ; % 試行数
        if strcmp(fileConditionName, conditionName)
            fprintf('S%02d %-7s: %d 試行（ファイル番号 %s）\n', ...
                iSubject, conditionName, nTrial, mat2str(TrialNumberArray)) ;
        else
            fprintf('S%02d %-7s: %d 試行 ← ファイル名 %s（命名ミス補正）（ファイル番号 %s）\n', ...
                iSubject, conditionName, nTrial, fileConditionName, mat2str(TrialNumberArray)) ;
        end

        for iTrial = 1:nTrial
            trialNumber = TrialNumberArray(iTrial) ; % ファイル名上の試行番号
            fileName = [sprintf('S%02d_', iSubject), fileConditionName, sprintf('%04d', trialNumber)] ; % sprintf：文字列に格納
            X = load_qualisys_mat(rawDataFolder, fileName) ; % load_qualisys_mat.mから帰ってきたデータをXに格納
            
            % 被験者間のマーカー名の揺れをここで吸収する（S01/S02 の Firtst → first）
            X.Markers = normalize_marker_names(X.Markers) ;

            X.SubjectID     = iSubject ;
            X.ConditionCode = iCondition ;
            X.ConditionName = conditionName ;
            X.SourceFileName = fileName ;   % 実際に読んだファイル名（追跡用）
            X.TrialNumber   = trialNumber ;
            X.ErrorCode     = 0 ;
            X.ErrorText     = '' ;

            % ---- top の最長連続NaN（記録全体。参考情報）----
            %  ★ 補間の前に測る。interp_nan_spline は Prm.MaxNumNans 以下の欠損を
            %    埋めてしまうため、後から測っても補間済みかどうか区別がつかない。
            %  ★ 除外の判定そのものは m3 が解析窓内で行う（§10.8 で範囲を確定）。
            %    ここで測るのは、除外の妥当性を後から追うための参考値。
            %  ★ 判定対象は top のみ。従来の
            %    any(cell2mat(struct2cell(HasLongNan))) は全マーカーを見ていたため、
            %    解析に使わない骨盤・手部の欠損でも試行に不良コードが付いていた
            %    （しかも下流から参照されておらず除外として機能していなかった）。
            %  詳細は技術説明 §10。
            topName = Prm.Excl.TopMarkerName ;
            if isfield(X.Markers, topName)
                X.MaxNanRunTop = maxNanRun(X.Markers.(topName)) ;
            else
                X.MaxNanRunTop = Inf ;          % top がラベル付けされていない試行
            end

            % interp nans
            [Markers_interp, ~] = interp_nan_spline(X.Markers, Prm.MaxNumNans) ;
            X.Markers = Markers_interp ;


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
               % ★ ErrorCode 99 の代入は廃止（下流から参照されていなかった）。
               %   床反力が無い試行は BWTail が NaN になるので x8 の IsBadGRF が拾う。
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
                DataArray(iTrial, iCondition).MaxNanRunTop  = Inf ;
            end
        end
    end


    dataFilePath = sprintf('x2_Data/Data%02d', iSubject) ;
    save(dataFilePath, 'DataArray')


    fprintf('保存完了 / Saved: %s.mat\n', dataFilePath) ;


    clear DataArray

end % iSubject


% -----------------------------------------------------------------------
% ローカル関数：各次元の最長連続NaN長を返す（記録全体）
%   判定範囲を解析窓内に変えたい場合は、呼び出し側で x(w,:) を渡す。
%   ただし x2 はまだ cue を判定していないため、その場合は判定を m3 へ移すこと
%   （技術説明 §10.4）。
% -----------------------------------------------------------------------
function n = maxNanRun(x)
n = 0 ;
for col = 1:size(x, 2)
    v      = double(isnan(x(:, col))) ;
    d      = diff([0 ; v ; 0]) ;
    starts = find(d ==  1) ;
    ends   = find(d == -1) - 1 ;
    if ~isempty(starts)
        n = max(n, max(ends - starts + 1)) ;
    end
end
end
