function plot_trials_with_mean_xy(XMat, YMat, lineColor)
% plot_trials_with_mean_xy  全試行のXY軌跡を薄く、平均軌跡を濃く重ねてプロットする
%   XMat, YMat : [nTrial x nTimePoints]（共通の時間軸に整列済み、NaN可）
%   lineColor  : [r g b]（0〜1）

hold on

hLines = plot(XMat', YMat', 'LineWidth', 0.5) ;
for h = hLines'
    h.Color = [lineColor, 0.15] ;
end

meanX = mean(XMat, 1, 'omitnan') ;
meanY = mean(YMat, 1, 'omitnan') ;
plot(meanX, meanY, 'Color', lineColor, 'LineWidth', 2.5) ;

end
