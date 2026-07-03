% ---- plot_trials_with_mean.m（新規ファイルとして作成）----
% 時間波形（横軸=時間、縦軸=値）用
function plot_trials_with_mean(tWin, WaveMat, lineColor)
% plot_trials_with_mean  全試行を薄く、平均波形を濃く重ねてプロットする
%   tWin      : 共通の時間軸 [1 x nTimePoints]（LED基準など）
%   WaveMat   : [nTrial x nTimePoints] 各試行の波形（NaNを含んでよい）
%   lineColor : [r g b]（0〜1）ベースとなる色。平均線はこの色そのもの、
%               個別試行はこの色を薄く（透明度を下げて）使う。

hold on

% ---- 全試行を薄く ----
% Line オブジェクトの Color に4番目の要素（アルファ値）を後から設定すると
% 透明度を付けられる（多くのMATLABバージョンで動作する一般的な方法）。
hLines = plot(tWin, WaveMat', 'LineWidth', 0.5) ;
for h = hLines'
    h.Color = [lineColor, 0.15] ;
end

% ---- 平均波形を濃く ----
meanWave = mean(WaveMat, 1, 'omitnan') ;
plot(tWin, meanWave, 'Color', lineColor, 'LineWidth', 2.5) ;

end