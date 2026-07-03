function boxplot_by_condition(dataMat, condNames, ylab)
% boxplot_by_condition  条件別データを箱ひげ図で表示する（NaNは除外）
%   dataMat   : [nTrial x nCondition] の数値行列（NaNを含んでよい）
%   condNames : 条件名のセル配列（例: {'free','simple','gonogo'}）
%   ylab      : Y軸ラベル文字列

vals = [] ;   grp = {} ;
for c = 1:numel(condNames)
    v = dataMat(~isnan(dataMat(:,c)), c) ;
    vals = [vals ; v] ;
    grp  = [grp ; repmat(condNames(c), numel(v), 1)] ;
end
if ~isempty(vals)
    boxplot(vals, grp, 'GroupOrder', condNames) ;
end
ylabel(ylab) ; grid on
end
