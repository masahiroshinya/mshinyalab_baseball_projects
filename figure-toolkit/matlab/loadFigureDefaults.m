function defaults = loadFigureDefaults(figureType)
% 図の既定値を読む：全種類に共通の値（figure-types/defaults.json）に、図の種類の値（figure-types/<種類>/defaults.json）を上書きする
%
% 入力：figureType ... 図の種類のフォルダ名（例：'timeseries'、'bar-points'、'scatter'）。空なら共通の値だけ
% 出力：defaults ... 既定値の struct（項目の意味は figure-types/README.md）
% 構造体の項目（例：fontSizePt）は、その中の項目ごとに上書きする（種類の defaults.json には違う値だけを書けばよい）

if nargin < 1
    figureType = '' ;
end
typesFolder = fullfile(toolkitPaths().toolkit, 'figure-types') ;
defaults = jsondecode(fileread(fullfile(typesFolder, 'defaults.json'))) ;
if ~isempty(figureType)
    typeFile = fullfile(typesFolder, figureType, 'defaults.json') ;
    if ~isfile(typeFile)
        error('loadFigureDefaults: %s がありません', typeFile) ;
    end
    defaults = mergeStruct(defaults, jsondecode(fileread(typeFile))) ;
end
defaults.figureType = figureType ;
end


% base の項目を override の項目で上書きする（両方が struct の項目は、中の項目ごとに上書きする）
function merged = mergeStruct(base, override)
merged = base ;
for name = fieldnames(override).'
    key = name{1} ;
    if isfield(merged, key) && isstruct(merged.(key)) && isstruct(override.(key))
        merged.(key) = mergeStruct(merged.(key), override.(key)) ;
    else
        merged.(key) = override.(key) ;
    end
end
end
