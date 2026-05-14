function Data = load_qualisys_mat(folderName, fileName)

% load_qualisys_mat
%
% Qualysis で計測し.mat形式にエキスポートされたデータをmatlabに読み込む
% 
% folderName: Qualysisからエキスポートされた.matファイルが存在するフォルダ名
% fileName: Qualysisからエキスポートされた.matファイルのファイル名
%
% last edited by SHINYA, 2017-08-21

%% 開発用
% clear
% close all
% folderName = [pwd, filesep, 'data'] ;
% fileName = 'UCM0001' ;

%% main code
% load mat file
filePath = [folderName, filesep, fileName] ;
load(filePath)

% name data structure as 'QualysisData'
QualysisData = eval(fileName) ;

% initialize output structure
Data = QualysisData ;
Data.Error = 0 ;

% marker trajectories
if isfield(QualysisData, 'Trajectories')
    if isfield(QualysisData.Trajectories, 'Labeled')
        if isfield(QualysisData.Trajectories.Labeled, 'Labels')
            MarkerNames = QualysisData.Trajectories.Labeled.Labels ;
            markerData = QualysisData.Trajectories.Labeled.Data ;
            nMarkers = QualysisData.Trajectories.Labeled.Count ;

            % marker data array
            markerArray = permute(markerData(:,1:3,:), [3,2,1]) ;

            % marker data structure
            for iMarker = 1:nMarkers
                fieldName = MarkerNames{iMarker} ;
                Markers.(fieldName) = markerArray(:,:,iMarker) ;
            end

            % output variable
            Data = rmfield(Data, 'Trajectories') ;
            Data.MarkerArray = markerArray ;
            Data.Markers = Markers ;
        end
    end
end


% force plates
if isfield(QualysisData, 'Force')
    
    % force の向きを変換（ヒトが+x方向に移動する力を+fxとする）
    force1  =  -Data.Force(1).Force' ;
    moment1 = Data.Force(1).Moment' ;
    force2  =  -Data.Force(2).Force' ;
    moment2 = Data.Force(2).Moment' ;
    
    % output variable
    Data.Force1 = force1 ;
    Data.Force2 = force2 ;
    Data.Moment1 = moment1 ;
    Data.Moment2 = moment2 ;
    Data.FPLocation1 = Data.Force(1).ForcePlateLocation ;
    Data.FPLocation2 = Data.Force(2).ForcePlateLocation ;
    
    Data = rmfield(Data, 'Force') ;
    
end


