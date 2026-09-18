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
%   スイング速度ピーク時Fz_条件別_全被験者.png（このスクリプトと同じフォルダ）
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

% ★ 呼び出し側で TargetSubjects を定義しておくと、その被験者だけを解析する。
%   （例: TargetSubjects = 6 ; i4_plot_fz_at_peakvel）
%   何も定義しなければ従来どおり全被験者を解析する。clearvars -except に
%   しておかないと、この先頭で呼び出し側の指定ごと消えてしまう。
clearvars -except TargetSubjects
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

lineColor = [0.60 0.60 0.60] ;

% ★ 条件の横位置（2026-09-15）。x 座標はすべて xC を経由させる（直に ic を
%   使うと、間隔を変えたときに片方だけ取り残されてずれる）。
% ★ 間隔を広げても、被験者ごとのずらし幅を同じ比率で広げると、軸が自動で
%   合わせにくるので絵は1ミリも変わらない。隙間を作りたいなら
%   「条件の間隔だけ」を広げ、ずらし幅は据え置く。
CondPitch  = 1.6 ;
xC         = 1 + ((1:nC) - 1) * CondPitch ;

% ★ 条件の中での被験者ごとの横位置。SubjColor と同じ並び。
%   ずらし幅は間隔に比例させない（上のとおり）。両端 ± 0.38、ジッタ ± 0.06 で
%   合計 ± 0.44 なので、条件どうしの間に 0.72 の隙間が空く。
SubjOffset = linspace(-0.38, 0.38, nS) ;
JitterW    = 0.12 ;
shadeCol  = [0.93 0.93 0.93] ;

% ★ 幅は i1 と同じ 1500 px にする。900 px だと表題と脚注が折り返して、
%   脚注が x 軸のラベルに重なった。
% ★ botPad は x 軸ラベル（約 35 px）と脚注3行（約 100 px）の両方を入れる。
%   足りないと脚注が条件名の上に乗る。
axH_px    = 340 ;      % パネルの高さ
topPad_px = 120 ;      % 図の上端からパネル上端まで（表題2行ぶん）
botPad_px = 165 ;      % パネル下端から図の下端まで（x 軸ラベル＋脚注3行）
figH      = topPad_px + axH_px + botPad_px ;

fig = figure('Color', 'w', 'Position', [80 80 1700 figH]) ;

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
patch(ax, xC(1) + CondPitch*[-0.5 0.5 0.5 -0.5], [yLo yLo yHi yHi], shadeCol, ...
    'EdgeColor', 'none') ;

% 個々の試行（被験者ごとに色を変え、横にずらして描く。i1 と同じ方針）
for ic = 1:nC
    for iS = 1:nS
        a = Vfz{iS,ic} ;
        if isempty(a), continue, end
        xj = xC(ic) + SubjOffset(iS) + (rand(numel(a),1) - 0.5) * JitterW ;
        scatter(ax, xj, a, 16, SubjColor(iS,:), 'filled', ...
            'MarkerFaceAlpha', 0.60, 'MarkerEdgeColor', 'none') ;
    end
end

% 被験者ごとの中央値（灰の折れ線）
subjMed = nan(nS, nC) ;
for iS = 1:nS
    for ic = 1:nC
        if ~isempty(Vfz{iS,ic}), subjMed(iS,ic) = median(Vfz{iS,ic}) ; end
    end
    % ★ 色は i0 の SubjColor（図をまたいで同じ被験者が同じ色になる）。
    plot(ax, xC, subjMed(iS,:), '-', 'Color', SubjColor(iS,:), 'LineWidth', 1.6, ...
        'Marker', 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'w', ...
        'MarkerEdgeColor', SubjColor(iS,:)) ;
end

% 条件の中央値（黒の太い横線）と四分位範囲（縦線）
for ic = 1:nC
    a = allByCond{ic} ;
    m = median(a) ; q1 = quantile(a,0.25) ; q3 = quantile(a,0.75) ;
    plot(ax, [xC(ic) xC(ic)], [q1 q3], 'k-', 'LineWidth', 1.2) ;
    % ★ 横線の幅は点の広がりに合わせる。点だけ広げると、横線が
    %   中央の被験者のものに見えてしまう。
    plot(ax, xC(ic) + [-0.46 0.46], [m m], 'k-', 'LineWidth', 3.0) ;
    text(ax, xC(ic), yHi, sprintf('%.1f', m), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', 15, 'FontWeight', 'bold') ;
    text(ax, xC(ic), yLo + 0.02*(yHi-yLo), sprintf('n=%d', numel(a)), ...
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
    % ★ 2026-09-18：ラベルの x を中央値の横線の右端より外に出した。被験者が
    %   1人だと、その中央値が条件の中央値と一致して黒い横線にラベルが重なる。
    text(ax, xC(nC) + 0.34*CondPitch, sv(k), sprintf('S%02d', SubjectArray(iS)), ...
        'FontSize', 10, 'FontWeight', 'bold', 'Color', SubjColor(iS,:), ...
        'VerticalAlignment', 'middle') ;
end

set(ax, 'XLim', [xC(1)-CondPitch*0.5, xC(nC)+CondPitch*0.55], 'YLim', [yLo yHi], ...
    'XTick', xC, 'XTickLabel', ConditionNameArray, ...
    'FontSize', 11, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], ...
    'GridAlpha', 1, 'Layer', 'bottom', 'Box', 'off') ;
ylabel(ax, 'スイング速度ピーク時の踏み込み足Fz [%BW]', 'FontSize', 12) ;

annotation('textbox', [0 (figH-42)/figH 1 34/figH], 'String', ...
    sprintf('バット先端の速度が最大になった瞬間の踏み込み足 Fz（%s・新しい除外基準）', GroupLabel), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 15, 'FontWeight', 'bold', 'EdgeColor', 'none') ;

annotation('textbox', [0 (figH-72)/figH 1 30/figH], 'String', ...
    ['黒い横線 = 条件の中央値（縦線は四分位範囲） / 色つきの折れ線 = 被験者ごとの中央値（色は被験者に対応） / ' ...
     '点 = 個々の試行（被験者ごとに横にずらしてある）   ※ free は自己ペース条件のため参考値（網掛け）'], ...
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

% ★ ファイル名は指標名を先頭に置く（2026-09-14。i1 と同じ方針）。
outPath = fullfile(thisDir, sprintf('スイング速度ピーク時Fz_条件別_%s.png', GroupTag)) ;
exportgraphics(fig, outPath, 'Resolution', 200) ;
fprintf('出力しました: %s\n', outPath) ;
