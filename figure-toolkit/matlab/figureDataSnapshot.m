function snapshot = figureDataSnapshot(target)
% 図に描かれているデータ（座標）を、体裁から切り離して記録する（compareFigureData で原案の図と比べるため）
%
% 入力：target ... axes または figure のハンドル（figure のときは、その中のすべての axes。凡例は含めない）
% 出力：snapshot（構造体）
%   .objects  データを描くオブジェクトごとの記録（構造体の配列。.kind 種類、.points 行が点の行列）
%             line      [x, y]（線と点。データのない代理の線（凡例用）は除く）
%             patch     [x, y]（fill の帯などの頂点）
%             bar       [x, y]（棒の位置と高さ）
%             errorbar  [x, y, 下側の長さ, 上側の長さ, 左側の長さ, 右側の長さ]
%             scatter   [x, y]
%             area      [x, y]
%             constantline  [軸（1 = x、2 = y）, 値]（xline・yline）
%   .texts    データ座標の文字（text）の一覧（cell の N×3：文字、x、y。位置の単位は text の Units のまま）
%   .limits   軸範囲（axes ごとの [xmin, xmax, ymin, ymax] の行）
% 点の順序は問わない（compareFigureData は、種類ごとに点を並べ替えてから比べる）。

if isa(target, 'matlab.ui.Figure')
    axesList = findobj(target, 'Type', 'axes') ;
else
    axesList = target ;
end

objects = struct('kind', {}, 'points', {}) ;
texts = cell(0, 3) ;
limits = zeros(0, 4) ;
for iAxes = 1:numel(axesList)
    ax = axesList(iAxes) ;
    limits(end + 1, :) = [ax.XLim, ax.YLim] ; %#ok<AGROW>
    children = ax.Children ;
    for iChild = 1:numel(children)
        child = children(iChild) ;
        kind = lower(child.Type) ;
        switch kind
            case {'line', 'patch', 'scatter', 'area', 'bar'}
                points = [double(child.XData(:)), double(child.YData(:))] ;
                points = points(~all(isnan(points), 2), :) ; % データのない代理の線（凡例用）・区切りの NaN を除く
            case 'errorbar'
                nPoints = numel(child.XData) ;
                points = [double(child.XData(:)), double(child.YData(:)), ...
                    zeroIfEmpty(child.YNegativeDelta, nPoints), zeroIfEmpty(child.YPositiveDelta, nPoints), ...
                    zeroIfEmpty(child.XNegativeDelta, nPoints), zeroIfEmpty(child.XPositiveDelta, nPoints)] ;
            case 'constantline'
                axisCode = 1 + strcmpi(child.InterceptAxis, 'y') ;
                points = [axisCode, double(child.Value)] ;
            case 'text'
                texts(end + 1, :) = {char(string(child.String)), child.Position(1), child.Position(2)} ; %#ok<AGROW>
                continue
            otherwise
                continue
        end
        if ~isempty(points)
            objects(end + 1) = struct('kind', kind, 'points', points) ; %#ok<AGROW>
        end
    end
end

snapshot = struct() ;
snapshot.objects = objects ;
snapshot.texts = texts ;
snapshot.limits = limits ;
end


% 誤差の長さ：指定のないもの（空）は 0 の列にする
function values = zeroIfEmpty(values, nPoints)
if isempty(values)
    values = zeros(nPoints, 1) ;
else
    values = double(values(:)) ;
end
end
