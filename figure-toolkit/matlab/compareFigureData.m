function isSame = compareFigureData(original, revised, label, annotations)
% 原案の図と論文用の図で、描いているデータが同じかを比べ、結果を表示する（元データを加工していないことの確認）
%
% 比べるもの：データを描くオブジェクトの座標（figureDataSnapshot）を、種類（line、patch、bar など）ごとに点の集まりとして比べる。
%   オブジェクトの分け方（例：3 本の棒を 1 つの bar で描くか、条件ごとに描くか）、描く順、色・線幅などの体裁は問わない。
% 原案にあって論文用の図にないもの：
%   原案で plot・text で描いた注釈（有意差のブラケットと記号、相関係数の文字など）は、論文用の図では Affinity の注釈
%   （exportPanel の JSON の annotations）になる。ブラケットの形の線（4 点：両端の縦線と横線）は、横の位置と高さが同じブラケットが
%   annotations にあれば、文字は同じ文字が annotations にあれば「注釈に置き換え」とし、不一致に数えない。
%   それ以外の、片方にしかないオブジェクトは一覧を出す。
% 論文用の図の軸範囲の外にある点（切れて見えなくなるデータ）があれば、その数を出す。
% 入力：
%   original     原案の図：axes・figure のハンドル、figureDataSnapshot の構造体、または exportPanel が書き出した <名前>_data.mat
%   revised      論文用の図：同上（ふつうは exportPanel が書き出した <名前>_data.mat）
%   label        表示の見出し（省略可。例：'Panel C'）
%   annotations  論文用の図の注釈（省略可。exportPanel の JSON の annotations、または JSON のファイル）。
%                revised が <名前>_data.mat のときは、同じフォルダの <名前>.json を自動で読む
% 出力：isSame ... データが一致し（置き換えた注釈を除く）、軸範囲の外の点がなければ true
% 使い方の例（原案のスクリプトが figure(3) に描く場合）：
%   run('draft_figures.m') ;
%   compareFigureData(figure(3), fullfile(toolkitPaths().input, '<図の名前>', '<パネルの名前>_data.mat'), 'Panel C')

if nargin < 3
    label = '' ;
end
if nargin < 4
    annotations = {} ;
    if (ischar(revised) || isstring(revised)) && endsWith(revised, '_data.mat')
        jsonPath = [extractBefore(char(revised), strlength(revised) - strlength('_data.mat') + 1), '.json'] ;
        if exist(jsonPath, 'file')
            annotations = jsonPath ;
        end
    end
end
originalSnapshot = toSnapshot(original) ;
revisedSnapshot = toSnapshot(revised) ;
annotations = toAnnotations(annotations) ;
relativeTolerance = 1e-9 ; % 数値の一致の許容（値の大きさに対する割合）

fprintf('== データの比較 %s\n', label) ;
isSame = true ;

% 原案のオブジェクトのうち、注釈に置き換えたもの（ブラケットの形の線）を除く
originalObjects = originalSnapshot.objects ;
isReplaced = false(1, numel(originalObjects)) ;
for iObject = 1:numel(originalObjects)
    if strcmp(originalObjects(iObject).kind, 'line')
        bracket = bracketOf(originalObjects(iObject).points) ;
        if ~isempty(bracket) && hasBracketAnnotation(annotations, bracket, relativeTolerance)
            isReplaced(iObject) = true ;
            fprintf('[--] 注釈に置き換え：ブラケット x [%g, %g]、高さ %g\n', bracket) ;
        end
    end
end
originalObjects = originalObjects(~isReplaced) ;
revisedObjects = revisedSnapshot.objects ;

% 種類ごとに、点の集まりを比べる
kinds = unique([{originalObjects.kind}, {revisedObjects.kind}]) ;
for iKind = 1:numel(kinds)
    kind = kinds{iKind} ;
    originalPoints = sortrows(vertcat(zeros(0, widthOf(kind)), originalObjects(strcmp({originalObjects.kind}, kind)).points)) ;
    revisedPoints = sortrows(vertcat(zeros(0, widthOf(kind)), revisedObjects(strcmp({revisedObjects.kind}, kind)).points)) ;
    isEqualKind = samePoints(originalPoints, revisedPoints, relativeTolerance) ;
    isSame = isSame && isEqualKind ;
    fprintf('[%s] %-12s 原案 %d 点、論文用 %d 点\n', okText(isEqualKind), kind, size(originalPoints, 1), size(revisedPoints, 1)) ;
    if ~isEqualKind
        reportUnmatched('原案だけ', originalObjects(strcmp({originalObjects.kind}, kind)), revisedPoints, relativeTolerance) ;
        reportUnmatched('論文用だけ', revisedObjects(strcmp({revisedObjects.kind}, kind)), originalPoints, relativeTolerance) ;
    end
end

% 論文用の図の軸範囲の外にある点（切れて見えなくなるデータ）。はみ出しの大きさを軸範囲の幅に対する割合で求め、
% 0.1 % を超えるものがあれば NG（0.1 % は、軸の長さ 50 mm で 0.05 mm。それ以下は見た目に分からないので、数だけを出す）
visibleExcessRatio = 1e-3 ;
if size(revisedSnapshot.limits, 1) == 1
    lim = revisedSnapshot.limits ;
    ranges = [lim(2) - lim(1), lim(4) - lim(3)] ;
    outsideCount = 0 ;
    maxExcessRatio = 0 ; % はみ出しの最大（軸範囲の幅に対する割合）
    for iObject = 1:numel(revisedObjects)
        if ismember(revisedObjects(iObject).kind, {'line', 'patch', 'scatter', 'bar', 'area'})
            xy = revisedObjects(iObject).points ;
            excessX = max(lim(1) - xy(:, 1), xy(:, 1) - lim(2))/ranges(1) ;
            excessY = max(lim(3) - xy(:, 2), xy(:, 2) - lim(4))/ranges(2) ;
            excess = max(excessX, excessY) ;
            outsideCount = outsideCount + sum(excess > relativeTolerance) ;
            maxExcessRatio = max([maxExcessRatio; excess]) ;
        end
    end
    isInside = maxExcessRatio <= visibleExcessRatio ;
    fprintf('[%s] 軸範囲の外の点 %d、はみ出しの最大は軸範囲の %.3g %%（論文用の図の軸範囲 x [%g, %g]、y [%g, %g]）\n', ...
        okText(isInside), outsideCount, 100*maxExcessRatio, lim) ;
    isSame = isSame && isInside ;
end

% 原案の文字：同じ文字が注釈にあれば置き換え、なければ一覧に出す（不一致に数えない。論文用の図に必要かは人が判断する）
annotationTexts = cellfun(@(item) strtrim(char(string(getFieldOr(item, 'text', '')))), annotations, 'UniformOutput', false) ;
for iText = 1:size(originalSnapshot.texts, 1)
    text = strtrim(originalSnapshot.texts{iText, 1}) ;
    if any(strcmp(annotationTexts, text))
        fprintf('[--] 注釈に置き換え：文字 "%s"\n', text) ;
    else
        fprintf('[--] 原案の文字（注釈にない）："%s"（x %g、y %g）\n', originalSnapshot.texts{iText, :}) ;
    end
end
% 判定は ASCII の OK・NG も出す（Windows の Git Bash では日本語の出力が文字化けすることがあるため）
fprintf('[summary] %s %s データは%s\n', ifElse(isSame, 'OK', 'NG'), label, ifElse(isSame, '一致', '一致しない')) ;
end


% 入力を figureDataSnapshot の構造体にする
function snapshot = toSnapshot(source)
if isstruct(source)
    snapshot = source ;
elseif ischar(source) || isstring(source)
    loaded = load(source, 'snapshot') ;
    snapshot = loaded.snapshot ;
else
    snapshot = figureDataSnapshot(source) ;
end
end

% 注釈を構造体の cell にする（JSON のファイル、JSON の構造体、構造体の配列、cell のいずれでもよい）
function annotations = toAnnotations(source)
if ischar(source) || isstring(source)
    spec = jsondecode(fileread(source)) ;
    source = getFieldOr(spec, 'annotations', {}) ;
end
if isempty(source)
    annotations = {} ; % 注釈がない（JSON の空の配列は double の [] になる）
elseif isstruct(source)
    annotations = num2cell(source(:)).' ;
else
    annotations = source ;
end
end

% 4 点のブラケットの形（両端が縦線、上が横線）なら [左の x, 右の x, 高さ] を返す。そうでなければ空
function bracket = bracketOf(points)
bracket = [] ;
if size(points, 1) ~= 4
    return
end
x = points(:, 1) ;
y = points(:, 2) ;
if x(1) == x(2) && x(3) == x(4) && y(2) == y(3) && y(1) == y(4) && y(1) < y(2) && x(1) < x(3)
    bracket = [x(1), x(3), y(2)] ;
end
end

function found = hasBracketAnnotation(annotations, bracket, relativeTolerance)
found = false ;
scale = max(1, max(abs(bracket))) ;
for iAnnotation = 1:numel(annotations)
    item = annotations{iAnnotation} ;
    if strcmp(getFieldOr(item, 'type', ''), 'bracket')
        candidate = [item.x(:).', item.y] ;
        if numel(candidate) == 3 && all(abs(candidate - bracket) <= relativeTolerance*scale)
            found = true ;
            return
        end
    end
end
end

% 片方にしかないオブジェクト（点がもう片方の点の集まりに含まれないもの）の一覧
function reportUnmatched(title, objects, otherPoints, relativeTolerance)
for iObject = 1:numel(objects)
    points = objects(iObject).points ;
    scale = max(1, max(abs(points(:)))) ;
    contained = all(ismembertol(points, otherPoints, relativeTolerance*scale, 'ByRows', true, 'DataScale', 1)) ;
    if ~contained
        fprintf('       %s：%s %d 点（x %g から %g、y %g から %g）\n', title, objects(iObject).kind, size(points, 1), ...
            min(points(:, 1)), max(points(:, 1)), min(points(:, 2)), max(points(:, 2))) ;
    end
end
end

function isEqual = samePoints(a, b, relativeTolerance)
isEqual = isequal(size(a), size(b)) && isequal(isnan(a), isnan(b)) ;
if isEqual && ~isempty(a)
    scale = max(1, max(abs(a(:)))) ;
    finite = ~isnan(a) ;
    isEqual = all(abs(a(finite) - b(finite)) <= relativeTolerance*scale) ;
end
end

function width = widthOf(kind)
width = 2 + 4*strcmp(kind, 'errorbar') ;
end

function value = getFieldOr(item, name, defaultValue)
if isstruct(item) && isfield(item, name)
    value = item.(name) ;
else
    value = defaultValue ;
end
end

function text = okText(condition)
text = ifElse(condition, 'OK', 'NG') ;
end

function value = ifElse(condition, trueValue, falseValue)
if condition
    value = trueValue ;
else
    value = falseValue ;
end
end
