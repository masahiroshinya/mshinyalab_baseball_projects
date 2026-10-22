function [fig, ax, style] = createPanelAxes(figureType)
% 単一パネルの図と軸を作り、作図方針（docs/figure-panel-style.md の 2・3 節）の体裁を設定する
%
% 既定値は figure-types/defaults.json（全種類に共通）と figure-types/<種類>/defaults.json（種類ごとの上書き）から読む。
% 図の大きさと軸の枠の位置（InnerPosition）は全パネルで共通にする。後でパネルを並べるとき、
% ページ単位で並べれば軸が揃うようにするため（docs/figure-assembly-style.md の 2 節のルール 2）。
% 入力：figureType ... 図の種類（figure-types のフォルダ名。例：'timeseries'）。省略時は共通の既定値だけ
% 出力：
%   fig, ax ... 図と軸（hold on 済み）
%   style   ... 既定値（図の大きさ、軸の位置、フォント、文字サイズ、線幅、配色、段の幅、種類ごとの値）
%             style.fontSize は目盛りの文字の大きさ（凡例・イベント線の名前にも使う）

if nargin < 1
    figureType = '' ;
end
style = loadFigureDefaults(figureType) ;
style.figureSizeCm = style.figureSizeCm(:).' ; % [幅, 高さ] [cm]
style.innerPositionCm = style.innerPositionCm(:).' ; % 軸の枠の左下の x・y と幅・高さ [cm]（図の左下が原点）
style.fontSize = style.fontSizePt.tickLabel ; % 目盛り・凡例の文字 [pt]（MATLAB から指定どおりに出るよう 0.75 pt の倍数にする）
style.lineWidth = style.lineWidthPt ; % 軸線・プロット線の線幅 [pt]
style.colours = style.colours/255 ; % 系列の色（行ごとに RGB、0〜1）
% 文字サイズ（2026-10-19 決定）：パネル記号 > 軸ラベル > 目盛り の大小関係を保つ（docs/figure-panel-style.md の 2 節）

% 図と軸（図の大きさと軸の枠の位置を固定）
fig = figure('Visible', 'off', 'Units', 'centimeters', 'Color', 'w') ;
fig.Position = [2, 2, style.figureSizeCm] ;
ax = axes(fig, 'Units', 'centimeters') ;
ax.PositionConstraint = 'innerposition' ;
ax.InnerPosition = style.innerPositionCm ;
hold(ax, 'on') ;

% 軸の体裁：フォント、文字サイズ、線幅、grid off、目盛りは外向き、軸の背景の矩形は出さない（docs/figure-panel-style.md の 5 節）
% 軸ラベルの大きさは、目盛りの大きさに対する倍率で指定する（7.5 pt × 1.2 = 9 pt）
ax.FontName = style.fontName ;
ax.FontSize = style.fontSizePt.tickLabel ;
ax.LabelFontSizeMultiplier = style.fontSizePt.axisLabel/style.fontSizePt.tickLabel ;
ax.LineWidth = style.lineWidth ;
ax.TickDir = 'out' ;
ax.Box = 'off' ;
ax.Color = 'none' ;
grid(ax, 'off') ;
end
