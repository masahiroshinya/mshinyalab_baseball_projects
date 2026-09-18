% p1_plot_by_condition.m
%
% 目的:
%   p0_calc_metrics.m が算出した4指標を、条件別_全被験者図の体裁で1枚にまとめて
%   PNG 出力する（5.7 の g1・5.8 の h1 と同じ作図コード）。
%
% 入力:
%   p0_calc_metrics.m が作る V, MetricName,
%   SubjectArray, ConditionNameArray, nS, nC, nM, Diag
%
% 出力:
%   条件別_全被験者_RT-MT-PeakVel-Slope_新除外基準.png（このスクリプトと同じフォルダ）
%
% 備考:
%   - 旧図 条件別_全被験者_RT-MT-PeakVel-Slope.png（2026-08-26）と並べて見る前提。
%     指標の定義は同一で、違うのは除外基準だけ（p0 のヘッダ参照）。
%   - free は自己ペース条件なので参考値（網掛け）。free の RT は
%     「cue からの反応」ではないので、特に参考値である。
%   - subplot の既定配置では sgtitle とパネルのタイトルが重なるため、
%     axes('Position', ...) で手動配置している。
%
% 2026-09-10

% ★ 呼び出し側で TargetSubjects を定義しておくと、その被験者だけを解析する。
%   （例: TargetSubjects = 6 ; p1_plot_by_condition）
%   何も定義しなければ従来どおり全被験者を解析する。clearvars -except に
%   しておかないと、この先頭で呼び出し側の指定ごと消えてしまう。
clearvars -except TargetSubjects
close all

% p0 を先頭で呼ぶ。p0 の中に clear ; close all があるので、
% 先に自分で変数を作っても消される。
p0_calc_metrics

% p0 が clear するので、出力先はここで取り直す。
thisDir = fileparts( mfilename('fullpath') ) ;


%% ---- 5. 描画 ----

dotColor  = [0.45 0.62 0.85] ;
lineColor = [0.60 0.60 0.60] ;
shadeCol  = [0.93 0.93 0.93] ;

nCol      = 2 ;
nRow      = ceil(nM / nCol) ;
axH_px    = 315 ;      % パネルの高さ
rowPitch  = 483 ;      % 行の間隔
topPad_px = 136.5 ;    % 図の上端から1行目のパネル上端まで（表題2行ぶん）
botPad_px = 205 ;      % 最終行のパネル下端から図の下端まで（脚注6行ぶん）

figH = topPad_px + axH_px*nRow + (rowPitch - axH_px)*(nRow-1) + botPad_px ;

fig = figure('Color', 'w', 'Position', [80 80 1500 figH]) ;

rng(0)   % ジッタを再現可能にする

for im = 1:nM

    col = mod(im-1, nCol) ;
    row = floor((im-1)/nCol) ;
    axPos = [0.07 + col*0.495, ...
             (figH - topPad_px - axH_px - rowPitch*row) / figH, ...
             0.40, axH_px/figH] ;
    ax = axes('Position', axPos) ;
    hold(ax, 'on')

    % 条件ごとの値をまとめる
    allByCond = cell(1, nC) ;
    for ic = 1:nC
        a = [] ;
        for iS = 1:nS
            a = [a ; V{iS,ic,im}] ;                                        %#ok<AGROW>
        end
        allByCond{ic} = a ;
    end

    % ---- y 範囲 ----
    %  ★ 極端な外れ値（top マーカーの座標が飛んだ試行）を軸に入れると、
    %    パネル全体が1本の帯に潰れて条件差が読めなくなる。四分位範囲の
    %    3倍で軸を切り、はみ出した点は境界に△▽で置いて数と値を注記する。
    %  ★ これは「表示の都合による軸の切り詰め」であって除外ではない。
    %    中央値・四分位範囲・n はすべて全試行から計算している。
    allv = vertcat(allByCond{:}) ;
    q1a  = quantile(allv, 0.25) ; q3a = quantile(allv, 0.75) ;
    iqra = q3a - q1a ;
    capLo = q1a - 3*iqra ;
    capHi = q3a + 3*iqra ;
    inCap = allv >= capLo & allv <= capHi ;

    lo = min(allv(inCap)) ; hi = max(allv(inCap)) ; pad = 0.10*(hi-lo) ;
    yLo = lo - pad*1.8 ;    % 下に n= の表示ぶんを確保
    yHi = hi + pad*0.6 ;

    % free の網掛け（参考値）— 点より先に描く
    patch(ax, [0.5 1.5 1.5 0.5], [yLo yLo yHi yHi], shadeCol, ...
        'EdgeColor', 'none') ;

    % 個々の試行（ジッタ散布）。軸外の点は境界に置く
    nOver = 0 ; nUnder = 0 ;
    for ic = 1:nC
        a  = allByCond{ic} ;
        xj = ic + (rand(numel(a),1) - 0.5) * 0.36 ;

        isIn = a >= yLo & a <= yHi ;
        scatter(ax, xj(isIn), a(isIn), 16, dotColor, 'filled', ...
            'MarkerFaceAlpha', 0.55, 'MarkerEdgeColor', 'none') ;

        isUp = a > yHi ;
        isDn = a < yLo ;
        if any(isUp)
            scatter(ax, xj(isUp), repmat(yHi, sum(isUp), 1), 34, [0.85 0.33 0.20], ...
                '^', 'filled', 'MarkerEdgeColor', 'none') ;
        end
        if any(isDn)
            scatter(ax, xj(isDn), repmat(yLo, sum(isDn), 1), 34, [0.85 0.33 0.20], ...
                'v', 'filled', 'MarkerEdgeColor', 'none') ;
        end
        nOver  = nOver  + sum(isUp) ;
        nUnder = nUnder + sum(isDn) ;
    end

    % 被験者ごとの中央値（灰の折れ線）
    subjMed = nan(nS, nC) ;
    for iS = 1:nS
        for ic = 1:nC
            if ~isempty(V{iS,ic,im}), subjMed(iS,ic) = median(V{iS,ic,im}) ; end
        end
        plot(ax, 1:nC, subjMed(iS,:), '-', 'Color', lineColor, 'LineWidth', 1.0, ...
            'Marker', 'o', 'MarkerSize', 5, 'MarkerFaceColor', 'w', ...
            'MarkerEdgeColor', lineColor*0.8) ;
    end

    % 条件の中央値（黒の太い横線）と四分位範囲（縦線）
    for ic = 1:nC
        a = allByCond{ic} ;
        if isempty(a), continue, end
        m = median(a) ; q1 = quantile(a,0.25) ; q3 = quantile(a,0.75) ;
        plot(ax, [ic ic], [q1 q3], 'k-', 'LineWidth', 1.2) ;
        plot(ax, ic + [-0.30 0.30], [m m], 'k-', 'LineWidth', 3.0) ;
        if abs(m) < 10, medFmt = '%.2f' ; else, medFmt = '%.1f' ; end
        text(ax, ic, yHi, sprintf(medFmt, m), 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 15, 'FontWeight', 'bold') ;
        text(ax, ic, yLo + 0.02*(yHi-yLo), sprintf('n=%d', numel(a)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 9, 'Color', [0.45 0.45 0.45]) ;
    end

    % 被験者ラベル（右端）。重なりを最小間隔で解消する
    lastCol = subjMed(:,nC) ;
    ok      = ~isnan(lastCol) ;
    [sv, order] = sort(lastCol(ok), 'descend') ;
    idxOK   = find(ok) ;
    minGap  = 0.058*(yHi-yLo) ;
    for k = 2:numel(sv)
        if sv(k-1) - sv(k) < minGap, sv(k) = sv(k-1) - minGap ; end
    end
    % ★ 2026-09-18：ラベルの x を中央値の横線の右端より外に出した。被験者が
    %   1人だと、その中央値が条件の中央値と一致して黒い横線にラベルが重なる。
    for k = 1:numel(order)
        iS = idxOK(order(k)) ;
        text(ax, nC+0.36, sv(k), sprintf('S%02d', SubjectArray(iS)), ...
            'FontSize', 10, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'middle') ;
    end

    % 軸外の点の注記（△▽ が何本で、実際の値がどこまで行っているか）
    if nOver > 0
        text(ax, 0.62, yHi, sprintf('\\uparrow 軸外 %d 点（最大 %.1f）', nOver, max(allv)), ...
            'Color', [0.85 0.33 0.20], 'FontSize', 9.5, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'top') ;
    end
    if nUnder > 0
        text(ax, 0.62, yLo + 0.055*(yHi-yLo), ...
            sprintf('\\downarrow 軸外 %d 点（最小 %.1f）', nUnder, min(allv)), ...
            'Color', [0.85 0.33 0.20], 'FontSize', 9.5, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom') ;
    end

    set(ax, 'XLim', [0.5 nC+0.55], 'YLim', [yLo yHi], ...
        'XTick', 1:nC, 'XTickLabel', ConditionNameArray, ...
        'FontSize', 11, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], ...
        'GridAlpha', 1, 'Layer', 'bottom', 'Box', 'off') ;
    title(ax, MetricName{im}, 'FontSize', 13, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0 1.13 0]) ;
end

annotation('textbox', [0 (figH-47.25)/figH 1 44.1/figH], 'String', ...
    sprintf(['反応時間課題バットスイング：条件別の全試行（%s・' ...
             '新しい除外基準／Go 試行 %d 本）'], GroupLabel, Diag.nGo), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 15, 'FontWeight', 'bold', 'EdgeColor', 'none') ;

annotation('textbox', [0 (figH-78.75)/figH 1 33.6/figH], 'String', ...
    ['黒い横線 = 条件の中央値（縦線は四分位範囲） / 灰の折れ線 = 被験者ごとの中央値 / ' ...
     '青点 = 個々の試行   ※ free は自己ペース条件のため参考値（網掛け）'], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10.5, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;

% ★ annotation は sprintf の書式を解釈しないので、パーセント記号は %% ではなく % と書く。
annotation('textbox', [0 8/figH 1 185/figH], 'String', ...
    {['指標の定義は旧図（2026-08-26）と同一。RT = Fx がベースライン中央値 + 0.20 ×（窓内ピーク − ベース）を 20 ms 超えた時点、' ...
      'MT = 最大速度の時点 − RT、Slope = 最大速度 ÷ MT'], ...
     ['★ 旧図との違いは除外基準だけ。旧図は値の範囲による事後フィルタ（PeakVel 5〜40 m/s・MT>0・RT 100〜600 ms）で 258→217 試行に絞っていた'], ...
     ['この図はそれを廃止し、03_Analysis 技術説明 §10.1 の2基準だけを使う。' ...
      '① top マーカーの欠損（解析窓 = cue 後 0〜2 s、x4 の IsBadTop）→ Peak velocity・MT・Slope を除外'], ...
     ['② 床反力が正常に計測できていない → RT・MT・Slope を除外。' ...
      'MT と Slope は両方に依存するので、①②のどちらかに掛かれば落ちる（そのため n が最も少ない）'], ...
     ['★ 残る外れ値：スイングを止めた試行（gostop）と、top マーカーの座標が飛んだ試行。' ...
      'S03 gonogo 行6 は 117.9 m/s（フレーム間変位 936 mm）で、欠損ではなく誤った座標が入っている（§9.4）'], ...
     ['橙の △▽ は軸の外にある点を境界に置いたもの。軸は四分位範囲の3倍で切ってあるが、' ...
      'これは表示の都合であって除外ではない（中央値・四分位範囲・n は全試行から計算）']}, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;


%% ---- 6. PNG 出力 ----

outPath = fullfile(thisDir, sprintf('条件別_%s_RT-MT-PeakVel-Slope_新除外基準.png', GroupTag)) ;
exportgraphics(fig, outPath, 'Resolution', 200) ;
fprintf('\n出力しました: %s\n', outPath) ;
