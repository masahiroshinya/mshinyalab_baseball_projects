% i4_plot_fz_at_peakvel.m
%
% 目的:
%   バット先端の速度が最大になった瞬間の、踏み込み足の鉛直床反力（Fz2）を
%   条件別に1枚で描く。
%   ★ i1 の図には混ぜない。この指標だけ top マーカー（除外基準①）に依存するので
%     n が他の5指標とそろわず、同じ図に並べるとパネルごとに母集団が違うことになる。
%
% 入力:
%   i0_calc_rfd_metrics.m が作る Rec（fzAtPV / peakVel を含む）,
%   SubjectArray, ConditionNameArray, nS, nC, Diag
%
% 出力:
%   条件別_全被験者_スイング速度ピーク時Fz.png（このスクリプトと同じフォルダ）
%
% 指標の定義:
%   スイング速度ピーク時の踏み込み足Fz [%BW]
%     バット先端の合成速度が cue 以降で最大になったフレームを探し、
%     その時刻の Fz2 を体重で割って %BW にしたもの。
%     ★ 速度のピークはマーカー（250 Hz）、Fz2 はアナログ（1000 Hz）で
%       サンプリングが違う。i0 の中で番号を × fsA/fsM して変換している。
%
% 備考:
%   - 体裁は i1（条件別_全被験者_Fz立ち上がり）に合わせてある。
%   - free は自己ペース条件なので参考値（網掛け）。
%   - ★ i1 と違い V ではなく Rec から値を取る。i0 が V に積んでいないため。
%
% 2026-09-11

clear ;
close all

% i0 を先頭で呼ぶ（i1・i3 と同じ。i0 の中に clear があるので順序は変えられない）。
i0_calc_rfd_metrics

% i0 が clear するので、出力先はここで取り直す。
thisDir = fileparts( mfilename('fullpath') ) ;


%% ---- 5. Rec から被験者 × 条件の値を取り出す ----

% ★ fzAtPV は top マーカーが欠けた試行で NaN になっている。ここで落とす。
Vfz = cell(nS, nC) ;

for iS = 1:nS
    for ic = 1:nC
        idx      = find([Rec.iS] == iS & [Rec.ic] == ic) ;
        a        = [Rec(idx).fzAtPV]' ;
        Vfz{iS,ic} = a(~isnan(a)) ;
    end
end

nUsed = sum( cellfun(@numel, Vfz(:)) ) ;
fprintf('\nスイング速度ピーク時の Fz2：%d 試行（5指標が揃った %d 試行のうち）\n', ...
    nUsed, Diag.nOK) ;


%% ---- 6. 描画（i1 と同じ体裁の1パネル）----

dotColor  = [0.45 0.62 0.85] ;
lineColor = [0.60 0.60 0.60] ;
shadeCol  = [0.93 0.93 0.93] ;

% ★ 幅は i1 と同じ 1500 px にする。900 px だと表題と脚注が折り返して、
%   脚注が x 軸のラベルに重なった。
% ★ botPad は x 軸ラベル（約 35 px）と脚注3行（約 100 px）の両方を入れる。
%   足りないと脚注が条件名の上に乗る。
axH_px    = 340 ;      % パネルの高さ
topPad_px = 120 ;      % 図の上端からパネル上端まで（表題2行ぶん）
botPad_px = 165 ;      % パネル下端から図の下端まで（x 軸ラベル＋脚注3行）
figH      = topPad_px + axH_px + botPad_px ;

fig = figure('Color', 'w', 'Position', [80 80 1500 figH]) ;

rng(0)   % ジッタを再現可能にする

ax = axes('Position', [0.07, botPad_px/figH, 0.86, axH_px/figH]) ;
hold(ax, 'on')

% 条件ごとの値をまとめる
allByCond = cell(1, nC) ;
for ic = 1:nC
    a = [] ;
    for iS = 1:nS
        a = [a ; Vfz{iS,ic}] ;                                             %#ok<AGROW>
    end
    allByCond{ic} = a ;
end

% y 範囲（外れ値を含めたうえで少し余白）
allv = vertcat(allByCond{:}) ;
lo = min(allv) ; hi = max(allv) ; pad = 0.10*(hi-lo) ;
yLo = lo - pad*1.8 ;    % 下に n= の表示ぶんを確保
yHi = hi + pad*0.6 ;

% free の網掛け（参考値）— 点より先に描く
patch(ax, [0.5 1.5 1.5 0.5], [yLo yLo yHi yHi], shadeCol, 'EdgeColor', 'none') ;

% 個々の試行（ジッタ散布）
for ic = 1:nC
    a  = allByCond{ic} ;
    xj = ic + (rand(numel(a),1) - 0.5) * 0.36 ;
    scatter(ax, xj, a, 16, dotColor, 'filled', 'MarkerFaceAlpha', 0.55, ...
        'MarkerEdgeColor', 'none') ;
end

% 被験者ごとの中央値（灰の折れ線）
subjMed = nan(nS, nC) ;
for iS = 1:nS
    for ic = 1:nC
        if ~isempty(Vfz{iS,ic}), subjMed(iS,ic) = median(Vfz{iS,ic}) ; end
    end
    plot(ax, 1:nC, subjMed(iS,:), '-', 'Color', lineColor, 'LineWidth', 1.0, ...
        'Marker', 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', lineColor*0.8) ;
end

% 条件の中央値（黒の太い横線）と四分位範囲（縦線）
for ic = 1:nC
    a = allByCond{ic} ;
    m = median(a) ; q1 = quantile(a,0.25) ; q3 = quantile(a,0.75) ;
    plot(ax, [ic ic], [q1 q3], 'k-', 'LineWidth', 1.2) ;
    plot(ax, ic + [-0.30 0.30], [m m], 'k-', 'LineWidth', 3.0) ;
    text(ax, ic, yHi, sprintf('%.1f', m), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 15, 'FontWeight', 'bold') ;
    text(ax, ic, yLo + 0.02*(yHi-yLo), sprintf('n=%d', numel(a)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', 9, 'Color', [0.45 0.45 0.45]) ;
end

% 被験者ラベル（右端）。重なりを最小間隔で解消する
[sv, order] = sort(subjMed(:,nC), 'descend') ;
minGap = 0.058*(yHi-yLo) ;
for k = 2:numel(sv)
    if sv(k-1) - sv(k) < minGap, sv(k) = sv(k-1) - minGap ; end
end
for k = 1:numel(order)
    iS = order(k) ;
    text(ax, nC+0.16, sv(k), sprintf('S%02d', SubjectArray(iS)), ...
        'FontSize', 10, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'middle') ;
end

set(ax, 'XLim', [0.5 nC+0.55], 'YLim', [yLo yHi], ...
    'XTick', 1:nC, 'XTickLabel', ConditionNameArray, ...
    'FontSize', 11, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], ...
    'GridAlpha', 1, 'Layer', 'bottom', 'Box', 'off') ;
ylabel(ax, 'スイング速度ピーク時の踏み込み足Fz [%BW]', 'FontSize', 12) ;

annotation('textbox', [0 (figH-42)/figH 1 34/figH], 'String', ...
    'バット先端の速度が最大になった瞬間の踏み込み足 Fz（5被験者・新しい除外基準）', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 15, 'FontWeight', 'bold', 'EdgeColor', 'none') ;

annotation('textbox', [0 (figH-72)/figH 1 30/figH], 'String', ...
    ['黒い横線 = 条件の中央値（縦線は四分位範囲） / 灰の折れ線 = 被験者ごとの中央値 / ' ...
     '青点 = 個々の試行   ※ free は自己ペース条件のため参考値（網掛け）'], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10.5, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;

% ★ annotation は sprintf の書式を解釈しないので、パーセント記号は %% ではなく % と書く。
annotation('textbox', [0 8/figH 1 100/figH], 'String', ...
    {['バット先端の合成速度が cue 以降で最大になった時刻の Fz2 を、推定体重で割って %BW にした値。' ...
      '速度はマーカー 250 Hz、Fz2 はアナログ 1000 Hz なので、番号を換算してから読んでいる'], ...
     ['★ n が i1 の図（条件別_全被験者_Fz立ち上がり）より少ないのは、この指標だけ top マーカーに依存するため。' ...
      '除外基準①（解析窓内の top の欠損）に掛かった試行では算出できない'], ...
     ['★ 独立した図にしてあるのは、母集団が違うパネルを同じ図に並べないため。' ...
      'i1 の5指標はすべて onset が取れた同じ試行集合を使っている']}, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;


%% ---- 7. PNG 出力 ----

outPath = fullfile(thisDir, '条件別_全被験者_スイング速度ピーク時Fz.png') ;
exportgraphics(fig, outPath, 'Resolution', 200) ;
fprintf('出力しました: %s\n', outPath) ;
