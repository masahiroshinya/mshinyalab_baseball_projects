% i2_plot_cv_by_condition.m
%
% ★ h2_plot_cv_by_condition.m の新しい除外基準版（2026-09-10）。
%   作図コードは h2 と同一で、呼ぶ算出スクリプトと出力ファイル名だけが違った。
%   比較を済ませたうえで h2 と旧 PNG は削除した（git 履歴から復元できる）。
%
% 目的:
%   i0_calc_rfd_metrics.m が算出した各指標について、
%   「被験者ごと・条件ごとの試行間変動係数（CV）」を算出して条件別に描画する。
%   ばらつきそのものを比較する図なので、i1（値そのものの図）とは別の1枚にする。
%
% 入力:
%   i0_calc_rfd_metrics.m が作る V, MetricName,
%   SubjectArray, ConditionNameArray, nS, nC, nM
%
% 出力:
%   条件別_全被験者_変動係数_新除外基準.png（このスクリプトと同じフォルダ）
%   CV      ... [被験者 × 条件 × 指標] の変動係数 [%]（SD / 平均）
%   CVrobust... 同・ロバスト版（(IQR/1.349) / 中央値）[%]
%   NTrial  ... [被験者 × 条件 × 指標] の試行数
%
% CV の定義:
%   CV [%] = 標準偏差 / 平均 × 100
%   ★ その被験者・その条件の「試行をまたいだ」ばらつき。1試行の中には各指標が
%      1個しかないので、変動係数は必ず試行間で取る。
%   ★ 被験者ごとに算出してから条件で比べる。全被験者を混ぜて1本の CV を出すと、
%      被験者間の水準差（体格・技術）がばらつきとして混入し、
%      「試行ごとにどれだけ揺れるか」という問いに答えられなくなる。
%
% 備考:
%   - CV は比尺度（ゼロ点に意味があり、正の値を取る）でしか意味を持たない。
%     本フォルダの5指標はすべて正の量なので条件を満たす。
%     ★ 5.7 の「ピーク後方GRF」のような負の指標に、そのまま当ててはいけない。
%   - 平均・SD は外れ値に弱いので、ロバスト版も算出してコンソールに並べる。
%     どちらを本採用にするかは §3-6 の比較を見て決める（未決）。
%   - 試行数が MinTrial 未満の被験者×条件は NaN にする（CV が不安定なため）。
%   - パネルの配置は i1 と同じ計算式。指標が増えても行が足される。

clear ;
close all

% i0 を先頭で呼ぶ。i0 の中に clear ; close all があるので、
% 先に自分で変数を作っても消される。
i0_calc_rfd_metrics

% i0 が clear するので、出力先はここで取り直す。
thisDir = fileparts( mfilename('fullpath') ) ;

MinTrial = 5 ;   % これ未満の試行数では CV を出さない


%% ---- 6. 変動係数の算出 ----

CV       = nan(nS, nC, nM) ;
CVrobust = nan(nS, nC, nM) ;
NTrial   = zeros(nS, nC, nM) ;

for im = 1:nM
    for iS = 1:nS
        for ic = 1:nC

            a = V{iS,ic,im} ;
            NTrial(iS,ic,im) = numel(a) ;
            if numel(a) < MinTrial, continue, end

            % 平均が 0 に近いと CV が発散する。本フォルダの指標では起きないが、
            % 指標を足したときのために番人を置いておく。
            if mean(a) <= 0, continue, end

            CV(iS,ic,im) = std(a) / mean(a) * 100 ;

            % ロバスト版：正規分布なら IQR/1.349 が SD の一致推定量になる
            iqrA = quantile(a,0.75) - quantile(a,0.25) ;
            CVrobust(iS,ic,im) = (iqrA/1.349) / median(a) * 100 ;
        end
    end
end


%% ---- 7. 検算（表）----

for im = 1:nM

    fprintf('\n===== CV [%%]  %s =====\n', MetricName{im}) ;
    fprintf('       |  free  | simple | gonogo | gostop |   （括弧内は試行数）\n') ;

    for iS = 1:nS
        fprintf(' S%02d   |', SubjectArray(iS)) ;
        for ic = 1:nC
            if isnan(CV(iS,ic,im))
                fprintf('   -    |') ;
            else
                fprintf(' %5.1f  |', CV(iS,ic,im)) ;
            end
        end
        fprintf('   (') ;
        fprintf('%d ', NTrial(iS,:,im)) ;
        fprintf(')\n') ;
    end

    fprintf('-------+--------+--------+--------+--------+\n') ;

    fprintf(' 中央値|') ;
    for ic = 1:nC
        fprintf(' %5.1f  |', median(CV(:,ic,im), 'omitnan')) ;
    end
    fprintf('\n ロバスト|') ;
    for ic = 1:nC
        fprintf(' %5.1f |', median(CVrobust(:,ic,im), 'omitnan')) ;
    end
    fprintf('\n') ;
end

%% ---- 7-2. CV を押し上げた被験者×条件を名指しする ----
% CV が中央値の 2 倍を超えたところは、たいてい1〜2試行の外れ値が原因である。
% 「どの被験者のどの条件を目視で見に行けばよいか」をここで出しておく。
% ★ CV は SD/平均なので、1試行の外れ値で簡単に倍になる。数字だけを見て
%    「この条件はばらつきが大きい」と結論してはいけない。

fprintf('\n--- CV が中央値の2倍を超えた被験者×条件（要目視確認）---\n') ;
for im = 1:nM
    med = median(CV(:,:,im), 'all', 'omitnan') ;
    for iS = 1:nS
        for ic = 1:nC
            if isnan(CV(iS,ic,im)) || CV(iS,ic,im) <= 2*med, continue, end
            a = V{iS,ic,im} ;
            fprintf('  S%02d %-7s %-28s CV=%5.1f%%  n=%2d  中央値 %.1f  範囲 %.1f 〜 %.1f\n', ...
                SubjectArray(iS), ConditionNameArray{ic}, MetricName{im}, ...
                CV(iS,ic,im), numel(a), median(a), min(a), max(a)) ;
        end
    end
end


% 確認すること
%   CV が 0〜60% のオーダーに収まるか。100% を超えるなら平均がゼロ付近まで
%     落ちている（比尺度として成立していない）ことを疑う。
%   通常版とロバスト版が大きく食い違う指標がないか。食い違うなら外れ値の影響が強い。
%   free の CV が他条件より大きいか（自己ペースなので大きくなるのが自然）。


%% ---- 8. 描画 ----
% i1 と違い、1点 = 1被験者（試行の散布はない。CV は被験者ごとに1個しか出ない）。

lineColor = [0.60 0.60 0.60] ;
shadeCol  = [0.93 0.93 0.93] ;
dotColor  = [0.45 0.62 0.85] ;

nCol      = 2 ;
nRow      = ceil(nM / nCol) ;
axH_px    = 315 ;
rowPitch  = 483 ;
topPad_px = 136.5 ;
botPad_px = 115.5 ;

figH = topPad_px + axH_px*nRow + (rowPitch - axH_px)*(nRow-1) + botPad_px ;

fig = figure('Color', 'w', 'Position', [80 80 1500 figH]) ;

for im = 1:nM

    col = mod(im-1, nCol) ;
    row = floor((im-1)/nCol) ;
    axPos = [0.07 + col*0.495, ...
             (figH - topPad_px - axH_px - rowPitch*row) / figH, ...
             0.40, axH_px/figH] ;
    ax = axes('Position', axPos) ;
    hold(ax, 'on')

    C = CV(:,:,im) ;

    % y 範囲。CV は 0 以上なので下端は 0 で止める（負の余白は意味がない）
    hi  = max(C(:)) ; pad = 0.10*hi ;
    yLo = -pad*1.1 ;      % 下に n= の表示ぶんを確保
    yHi = hi + pad*0.6 ;

    % free の網掛け（参考値）
    patch(ax, [0.5 1.5 1.5 0.5], [yLo yLo yHi yHi], shadeCol, 'EdgeColor', 'none') ;
    yline(ax, 0, '-', 'Color', [0.80 0.80 0.80]) ;

    % 被験者ごとの CV（点と折れ線）
    for iS = 1:nS
        plot(ax, 1:nC, C(iS,:), '-', 'Color', lineColor, 'LineWidth', 1.0, ...
            'Marker', 'o', 'MarkerSize', 7, 'MarkerFaceColor', dotColor, ...
            'MarkerEdgeColor', lineColor*0.8) ;
    end

    % 5名の中央値（黒の太い横線）と四分位範囲（縦線）
    for ic = 1:nC
        a = C(:,ic) ; a = a(~isnan(a)) ;
        if isempty(a), continue, end
        m = median(a) ; q1 = quantile(a,0.25) ; q3 = quantile(a,0.75) ;
        plot(ax, [ic ic], [q1 q3], 'k-', 'LineWidth', 1.2) ;
        plot(ax, ic + [-0.30 0.30], [m m], 'k-', 'LineWidth', 3.0) ;
        text(ax, ic, yHi, sprintf('%.1f', m), 'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'bottom', 'FontSize', 15, 'FontWeight', 'bold') ;
        % ここでの n は「試行数」ではなく「CV を出せた被験者の数」
        text(ax, ic, yLo + 0.02*(yHi-yLo), sprintf('%d名', numel(a)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 9, 'Color', [0.45 0.45 0.45]) ;
    end

    % 被験者ラベル（右端）。重なりを最小間隔で解消する
    [sv, order] = sort(C(:,nC), 'descend') ;
    minGap = 0.058*(yHi-yLo) ;
    for k = 2:numel(sv)
        if sv(k-1) - sv(k) < minGap, sv(k) = sv(k-1) - minGap ; end
    end
    for k = 1:numel(order)
        if isnan(sv(k)), continue, end
        text(ax, nC+0.16, sv(k), sprintf('S%02d', SubjectArray(order(k))), ...
            'FontSize', 10, 'Color', [0.35 0.35 0.35], 'VerticalAlignment', 'middle') ;
    end

    set(ax, 'XLim', [0.5 nC+0.55], 'YLim', [yLo yHi], ...
        'XTick', 1:nC, 'XTickLabel', ConditionNameArray, ...
        'FontSize', 11, 'YGrid', 'on', 'GridColor', [0.85 0.85 0.85], ...
        'GridAlpha', 1, 'Layer', 'bottom', 'Box', 'off') ;
    title(ax, sprintf('CV：%s', MetricName{im}), 'FontSize', 13, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0 1.13 0]) ;
    ylabel(ax, 'CV [%]') ;
end

annotation('textbox', [0 (figH-47.25)/figH 1 44.1/figH], 'String', ...
    '反応時間課題バットスイング：条件別の試行間変動係数（被験者内・5被験者・新しい除外基準）', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 15, 'FontWeight', 'bold', 'EdgeColor', 'none') ;

annotation('textbox', [0 (figH-78.75)/figH 1 33.6/figH], 'String', ...
    ['青点 = 被験者1名の CV（その条件の全試行から算出） / 灰の折れ線 = 同一被験者 / ' ...
     '黒い横線 = 5名の中央値（縦線は四分位範囲）   ※ free は自己ペース条件のため参考値（網掛け）'], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10.5, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;

% ★ annotation は sprintf の書式を解釈しないので、パーセント記号は %% ではなく % と書く。
annotation('textbox', [0 5.25/figH 1 78.75/figH], 'String', ...
    {'CV [%] = その被験者・その条件における、試行をまたいだ 標準偏差 ÷ 平均 × 100', ...
     ['被験者ごとに算出してから条件で比べている。全被験者を混ぜて1本の CV を出すと、' ...
      '被験者間の水準差がばらつきとして混入する'], ...
     '下段の「n名」は試行数ではなく、CV を算出できた被験者の人数（試行数 5 未満の被験者×条件は除外）'}, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;


%% ---- 9. PNG 出力 ----

outPath = fullfile(thisDir, '条件別_全被験者_変動係数_新除外基準.png') ;
exportgraphics(fig, outPath, 'Resolution', 200) ;
fprintf('\n出力しました: %s\n', outPath) ;
