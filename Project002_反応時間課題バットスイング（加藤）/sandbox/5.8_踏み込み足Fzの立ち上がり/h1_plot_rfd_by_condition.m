% h1_plot_rfd_by_condition.m
%
% 目的:
%   h0_calc_rfd_metrics.m が算出した指標を、5.6 / 5.7 の「条件別_全被験者」図と
%   同じ体裁で1枚にまとめて PNG 出力する。
%
% 入力:
%   h0_calc_rfd_metrics.m が作る V, BWest, MetricName,
%   SubjectArray, ConditionNameArray, nS, nC, nM
%
% 出力:
%   条件別_全被験者_Fz立ち上がり.png（このスクリプトと同じフォルダ）
%
% 備考:
%   - 算出は h0 に分離した。指標の定義は h0 のヘッダを参照。
%   - free は自己ペース条件なので参考値（網掛け）。
%     free の RT は「cue からの反応」ではないので、特に参考値である。
%   - subplot の既定配置では sgtitle とパネルのタイトルが重なるため、
%     axes('Position', ...) で手動配置している。
%   - ★ パネルの配置は nM から計算する（2026-09-07 に指標を5個に増やした際、
%     2 行決め打ちから変更）。列数は 2 のままで、指標が増えると行が足される。
%     余白は px で決めてから正規化しているので、行が増えても見た目が変わらない。

clear ;
close all

% h0 を先頭で呼ぶ。h0 の中に clear ; close all があるので、
% 先に自分で変数を作っても消される。
h0_calc_rfd_metrics

% h0 が clear するので、出力先はここで取り直す。
thisDir = fileparts( mfilename('fullpath') ) ;


%% ---- 5. 描画（5.7 の条件別図と同じ体裁）----

dotColor  = [0.45 0.62 0.85] ;
lineColor = [0.60 0.60 0.60] ;
shadeCol  = [0.93 0.93 0.93] ;

% ---- パネルの配置を nM から決める ----
% 行間の 168 px（rowPitch - axH_px）がパネルのタイトルと中央値の数字の場所になる。
nCol      = 2 ;
nRow      = ceil(nM / nCol) ;
axH_px    = 315 ;      % パネルの高さ
rowPitch  = 483 ;      % 行の間隔
topPad_px = 136.5 ;    % 図の上端から1行目のパネル上端まで（表題2行ぶん）
botPad_px = 115.5 ;    % 最終行のパネル下端から図の下端まで（脚注ぶん）

figH = topPad_px + axH_px*nRow + (rowPitch - axH_px)*(nRow-1) + botPad_px ;

fig = figure('Color', 'w', 'Position', [80 80 1500 figH]) ;

rng(0)   % ジッタを再現可能にする

for im = 1:nM

    % subplot 既定の配置だと表題とパネルのタイトルが重なるので手動配置にする。
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

    % y 範囲（外れ値を含めたうえで少し余白）
    allv = vertcat(allByCond{:}) ;
    lo = min(allv) ; hi = max(allv) ; pad = 0.10*(hi-lo) ;
    yLo = lo - pad*1.8 ;    % 下に n= の表示ぶんを確保
    yHi = hi + pad*0.6 ;

    % free の網掛け（参考値）— 波形より先に描く
    patch(ax, [0.5 1.5 1.5 0.5], [yLo yLo yHi yHi], shadeCol, ...
        'EdgeColor', 'none') ;

    % 個々の試行（ジッタ散布）
    for ic = 1:nC
        a = allByCond{ic} ;
        xj = ic + (rand(numel(a),1) - 0.5) * 0.36 ;
        scatter(ax, xj, a, 16, dotColor, 'filled', 'MarkerFaceAlpha', 0.55, ...
            'MarkerEdgeColor', 'none') ;
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
        m = median(a) ; q1 = quantile(a,0.25) ; q3 = quantile(a,0.75) ;
        plot(ax, [ic ic], [q1 q3], 'k-', 'LineWidth', 1.2) ;
        plot(ax, ic + [-0.30 0.30], [m m], 'k-', 'LineWidth', 3.0) ;
        % 上部に中央値、下部に n
        % 1/s の指標は 1〜2 のオーダーなので、小数1桁だと条件差が潰れる
        if abs(m) < 10, medFmt = '%.2f' ; else, medFmt = '%.1f' ; end
        text(ax, ic, yHi, sprintf(medFmt, m), 'HorizontalAlignment', 'center', ...
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
    title(ax, MetricName{im}, 'FontSize', 13, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0 1.13 0]) ;
end

annotation('textbox', [0 (figH-47.25)/figH 1 44.1/figH], 'String', ...
    '反応時間課題バットスイング：踏み込み足 Fz の立ち上がり（5被験者）', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 15, 'FontWeight', 'bold', 'EdgeColor', 'none') ;

annotation('textbox', [0 (figH-78.75)/figH 1 33.6/figH], 'String', ...
    ['黒い横線 = 条件の中央値（縦線は四分位範囲） / 灰の折れ線 = 被験者ごとの中央値 / ' ...
     '青点 = 個々の試行   ※ free は自己ペース条件のため参考値（網掛け）'], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10.5, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;

% 定義の断り書きは下端に置く（上に置くとパネルのタイトルと衝突する）。
% ★ annotation は sprintf の書式を解釈しないので、パーセント記号は %% ではなく % と書く。
annotation('textbox', [0 5.25/figH 1 78.75/figH], 'String', ...
    {['RT は 5.6 の定義（Fx がベースライン + 0.20 ×（窓内ピーク − ベース）を 20 ms 超えた時点）。' ...
      '分母は記録末端 0.5 s から推定した体重（S01 74.6・S02 87.4・S03 60.5・S04 72.3・S05 69.9 kg）'], ...
     ['力の立ち上がり速度 =（Fz2ピーク − RT時点の Fz2）÷ 体重 × 100 ÷（RT → ピーク の秒数）。' ...
      'ピークの探索窓は cue から 2 s（5.7 の g0 と同じ）'], ...
     ['立ち上がり速度 ÷ ピーク力 [1/s] は、達成した力の大きさで割った正規化 RFD。' ...
      'RT 時点の Fz2 がほぼ 0（踏み込み足が空中）なので、実質 1 ÷（RT → ピーク の秒数）になる'], ...
     'ピーク鉛直GRF の n が他より多いのは、onset が取れなかった試行でもピークだけは算出できるため'}, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;


%% ---- 6. PNG 出力 ----

outPath = fullfile(thisDir, '条件別_全被験者_Fz立ち上がり.png') ;
exportgraphics(fig, outPath, 'Resolution', 200) ;
fprintf('出力しました: %s\n', outPath) ;
