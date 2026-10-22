% 跳躍高の条件比較：スクワットジャンプ（SJ）、反動あり（CMJ）、反動と腕の振りあり（CMJ+AS）（ダミーデータ）
%
% 図の種類：bar-points（棒と個人の点。recipe.md）。
% 平均（棒）± SD（誤差棒）と、各参加者の値（点）を参加者ごとに線で結ぶ（反復測定）。誤差棒は棒の背面に置く（既定）。
% Affinity で加える注釈：条件間の有意差記号（ブラケットと *。有意かどうかだけを示し、p の大きさで記号を変えない）。
% 跳躍高は非負の量なので、縦軸は 0 から切りのよい値までとする（docs/figure-panel-style.md の 1 節）。
% 実行：matlab -batch "addpath('<figure-toolkit>/matlab') ; run('<figure-toolkit>/figure-types/bar-points/example_jump_height.m')"

outDir = fullfile(toolkitPaths().input, 'panels') ;

% ダミーデータ：参加者 × 条件の跳躍高 [cm]
rng(2) ;
nParticipants = 10 ;
conditionNames = {'SJ', 'CMJ', 'CMJ+AS'} ;
nConditions = numel(conditionNames) ;
squatJumpHeight = 30 + 4*randn(nParticipants, 1) ; % SJ の跳躍高 [cm]
countermovementGain = 3 + 1.2*randn(nParticipants, 1) ; % 反動による増加 [cm]
armSwingGain = 6 + 1.5*randn(nParticipants, 1) ; % 腕の振りによる増加 [cm]
jumpHeight = [squatJumpHeight, ...
              squatJumpHeight + countermovementGain, ...
              squatJumpHeight + countermovementGain + armSwingGain] ;
meanHeight = mean(jumpHeight, 1) ;
sdHeight = std(jumpHeight, 0, 1) ;

% 条件間の比較：対応のある t 検定（Bonferroni 補正、3 組）。有意差記号の文字を決める
comparisonPairs = [1, 2; 2, 3; 1, 3] ;
nComparisons = size(comparisonPairs, 1) ;
pValues = zeros(nComparisons, 1) ;
for iComparison = 1:nComparisons
    difference = jumpHeight(:, comparisonPairs(iComparison, 2)) - jumpHeight(:, comparisonPairs(iComparison, 1)) ;
    tValue = mean(difference)/(std(difference)/sqrt(nParticipants)) ;
    pValues(iComparison) = min(1, nComparisons*twoTailedP(tValue, nParticipants - 1)) ;
end

% 縦軸の範囲：有意差記号の分の余白を含めて 0〜50 cm
yLimit = 50 ; % [cm]
maxHeight = max(jumpHeight(:)) ;
bracketLevel = ceil(maxHeight) + [2, 2, 6] ; % 各比較のブラケットの高さ [cm]（隣り合う比較は同じ高さ、両端の比較は上）
if max(bracketLevel) + 4 > yLimit
    error('有意差記号が縦軸の範囲 %g cm に収まりません（最大値 %.1f cm）', yLimit, maxHeight) ;
end

% 作図：誤差棒（既定では棒より先に描いて背面に置く）、棒（条件ごとに 1 つの Bar）、参加者ごとの線、条件ごとの点
[fig, ax, style] = createPanelAxes('bar-points') ;
conditionColours = style.colours([1, 2, 3], :) ;
barShare = style.barColourPercent/100 ; % 棒の塗り：条件の色の割合（残りは白）
paleColours = barShare*conditionColours + (1 - barShare) ;
drawErrorBars = @() errorbar(ax, 1:nConditions, meanHeight, sdHeight, 'k', 'LineStyle', 'none', 'LineWidth', style.lineWidth) ;
if style.errorBarsBehindBars
    errorBarHandle = drawErrorBars() ;
end
barHandles = gobjects(1, nConditions) ;
for iCondition = 1:nConditions
    barHandles(iCondition) = bar(ax, iCondition, meanHeight(iCondition), style.barWidth, 'FaceColor', paleColours(iCondition, :), ...
        'EdgeColor', 'k', 'LineWidth', style.lineWidth, 'ShowBaseLine', 'off') ;
end
participantLineHandles = gobjects(nParticipants, 1) ;
for iParticipant = 1:nParticipants
    participantLineHandles(iParticipant) = plot(ax, 1:nConditions, jumpHeight(iParticipant, :), 'Color', style.participantLineColour(:).'/255, ...
        'LineWidth', style.lineWidth) ;
end
markerHandles = gobjects(1, nConditions) ;
for iCondition = 1:nConditions
    markerHandles(iCondition) = plot(ax, iCondition*ones(nParticipants, 1), jumpHeight(:, iCondition), 'LineStyle', 'none', ...
        'Marker', 'o', 'MarkerSize', style.markerSizePt, 'MarkerFaceColor', conditionColours(iCondition, :), 'MarkerEdgeColor', 'none') ;
end
if ~style.errorBarsBehindBars
    errorBarHandle = drawErrorBars() ;
end

% 軸
xlim(ax, [0.4, nConditions + 0.6]) ;
ylim(ax, [0, yLimit]) ;
xticks(ax, 1:nConditions) ;
xticklabels(ax, conditionNames) ;
yticks(ax, 0:10:yLimit) ;
ylabel(ax, 'Jump height (cm)') ;

% Affinity で加える注釈（位置はデータ座標）：有意差のブラケットと記号。隣り合う比較は端を少し内側に寄せる
annotations = cell(1, nComparisons) ;
for iComparison = 1:nComparisons
    pair = comparisonPairs(iComparison, :) ;
    isAdjacent = pair(2) - pair(1) == 1 ;
    inset = 0.06*isAdjacent ; % 隣り合うブラケットが x = 2 で接しないように端を寄せる量 [条件の間隔]
    annotations{iComparison} = struct('type', 'bracket', 'name', sprintf('significance %s-%s', conditionNames{pair}), ...
        'x', [pair(1) + inset, pair(2) - inset], 'y', bracketLevel(iComparison), 'legMm', 1.0, ...
        'text', significanceSymbol(pValues(iComparison)), 'textGapMm', 0.5) ; % textGapMm：ブラケットと記号の字形の下端の間隔
end

% 書き出し：成分は背面から前面の順（誤差棒は既定では棒の背面）
dataComponents = { ...
    'bars SJ', barHandles(1) ; ...
    'bars CMJ', barHandles(2) ; ...
    'bars CMJ+AS', barHandles(3) ; ...
    'lines participants', participantLineHandles ; ...
    'markers SJ', markerHandles(1) ; ...
    'markers CMJ', markerHandles(2) ; ...
    'markers CMJ+AS', markerHandles(3)} ;
if style.errorBarsBehindBars
    dataComponents = [{'error bars', errorBarHandle}; dataComponents] ;
else
    dataComponents = [dataComponents; {'error bars', errorBarHandle}] ;
end
spec = struct() ;
spec.name = 'jump_height' ;
spec.panel = 'A' ;
spec.outDir = outDir ;
spec.style = style ;
spec.components = [dataComponents; {'axes', []}] ;
spec.legend = [] ;
spec.annotations = annotations ;
exportPanel(fig, ax, spec) ;
fprintf('mean (SD) [cm]: %s\n', sprintf('%.1f (%.1f)  ', [meanHeight; sdHeight])) ;
fprintf('corrected p: %s; max %.1f cm\n', sprintf('%.4f ', pValues), maxHeight) ;
close(fig) ;


%% 関数

% t 値と自由度から両側の p 値を求める（Statistics Toolbox の tcdf を使わず、不完全ベータ関数で計算する）
function p = twoTailedP(tValue, degreesOfFreedom)
p = betainc(degreesOfFreedom/(degreesOfFreedom + tValue^2), degreesOfFreedom/2, 0.5) ;
end

% p 値から有意差記号の文字を決める（有意かどうかだけを示す。p の大きさで記号の数を変えない：2026-10-19、ユーザーの方針）
function symbol = significanceSymbol(p)
if p < 0.05
    symbol = '*' ;
else
    symbol = 'n.s.' ;
end
end
