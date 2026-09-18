% i1_plot_rfd_by_condition.m
%
% ★ h1_plot_rfd_by_condition.m の新しい除外基準版（2026-09-10）。
%   作図コードは h1 と同一で、呼ぶ算出スクリプトと出力ファイル名だけが違った。
%   比較を済ませたうえで h1 と旧 PNG は削除した（git 履歴から復元できる）。
%
% 目的:
%   i0_calc_rfd_metrics.m が算出した指標を、5.6 / 5.7 の「条件別_全被験者」図と
%   同じ体裁で1枚にまとめて PNG 出力する。
%
% 入力:
%   i0_calc_rfd_metrics.m が作る V, BWest, MetricName,
%   SubjectArray, ConditionNameArray, nS, nC, nM
%
% 出力（このスクリプトと同じフォルダ）:
%   Fz立ち上がり_条件別_全被験者.png ... 5指標を1枚にまとめた図
%   個別グラフ/01_RT.png 〜 05_立ち上がり速度わりピーク力.png
%     ... 同じパネルを指標ごとに1枚ずつ書き出したもの（スライドや原稿に貼る用）
%
% 備考:
%   - 算出は i0 に分離した。指標の定義は i0 のヘッダを参照。
%   - free は自己ペース条件なので参考値（網掛け）。
%     free の RT は「cue からの反応」ではないので、特に参考値である。
%   - subplot の既定配置では sgtitle とパネルのタイトルが重なるため、
%     axes('Position', ...) で手動配置している。
%   - ★ パネルの配置は nM から計算する（2026-09-07 に指標を5個に増やした際、
%     2 行決め打ちから変更）。列数は 2 のままで、指標が増えると行が足される。
%     余白は px で決めてから正規化しているので、行が増えても見た目が変わらない。

% ★ 呼び出し側で TargetSubjects を定義しておくと、その被験者だけを解析する。
%   （例: TargetSubjects = 6 ; i1_plot_rfd_by_condition）
%   何も定義しなければ従来どおり全被験者を解析する。clearvars -except に
%   しておかないと、この先頭で呼び出し側の指定ごと消えてしまう。
clearvars -except TargetSubjects
close all

% i0 を先頭で呼ぶ。i0 の中に clear ; close all があるので、
% 先に自分で変数を作っても消される。
i0_calc_rfd_metrics

% i0 が clear するので、出力先はここで取り直す。
thisDir = fileparts( mfilename('fullpath') ) ;


%% ---- 5. 描画（5.7 の条件別図と同じ体裁）----

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

% ---- パネルの配置を nM から決める ----
% 行間の 168 px（rowPitch - axH_px）がパネルのタイトルと中央値の数字の場所になる。
nCol      = 2 ;
nRow      = ceil(nM / nCol) ;
axH_px    = 315 ;      % パネルの高さ
rowPitch  = 483 ;      % 行の間隔
topPad_px = 136.5 ;    % 図の上端から1行目のパネル上端まで（表題2行ぶん）
botPad_px = 265 ;      % 最終行のパネル下端から図の下端まで（脚注8行ぶん）

figH = topPad_px + axH_px*nRow + (rowPitch - axH_px)*(nRow-1) + botPad_px ;

% ★ 条件の間隔を広げたぶん、図の幅も広げる。幅を据え置くと
%   1条件あたりの px が減り、点の塊が細くなるだけで読みやすくならない。
fig = figure('Color', 'w', 'Position', [80 80 1900 figH]) ;

rng(0)   % ジッタを再現可能にする

% ★ 個別 PNG は、描き終えたパネルを copyobj で新しい図に移して書き出す。
%   同じ描画コードを2回書くと、片方だけ直して見た目がずれる。
%   ファイル名は %・÷・→ を避けた別名にする（そのままだとパスに使えない）。
AxList   = gobjects(1, nM) ;
FileName = {'RT', 'ピーク鉛直GRF', 'OnsetからFzピークまでの時間', ...
            '力の立ち上がり速度', '立ち上がり速度わりピーク力'} ;

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
    patch(ax, xC(1) + CondPitch*[-0.5 0.5 0.5 -0.5], [yLo yLo yHi yHi], shadeCol, ...
        'EdgeColor', 'none') ;

    % 個々の試行（被験者ごとに色を変え、横にずらして描く）
    % ★ 2026-09-15：全被験者ぶんを1色・同じ位置に重ねていたので、点の塊が
    %   どの被験者のものか読めなかった。折れ線と同じ色にし、条件の中で
    %   被験者ごとに横位置を分ける。
    % ★ ずらし幅は条件の中央値の横線（ic ± 0.30）に収まる範囲にする。
    %   はみ出すと隣の条件の点と混ざって、どちらの条件か分からなくなる。
    for ic = 1:nC
        for iS = 1:nS
            a = V{iS,ic,im} ;
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
            if ~isempty(V{iS,ic,im}), subjMed(iS,ic) = median(V{iS,ic,im}) ; end
        end
        % ★ 灰一色だと折れ線の交差で被験者を追えない。i0 が決めた色を使う
        %   （図をまたいで同じ被験者が同じ色になる）。線を太くしないと
        %   細線では色が判別しにくい。
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
        % 上部に中央値、下部に n
        % 1/s の指標は 1〜2 のオーダーなので、小数1桁だと条件差が潰れる
        if abs(m) < 10, medFmt = '%.2f' ; else, medFmt = '%.1f' ; end
        text(ax, xC(ic), yHi, sprintf(medFmt, m), 'HorizontalAlignment', 'center', ...
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
        % ★ ラベルも線と同じ色にする。重なり回避で位置をずらしているので、
        %   色がないとどの線のラベルか分からなくなる。
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
    title(ax, MetricName{im}, 'FontSize', 13, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', 'Units', 'normalized', 'Position', [0 1.13 0]) ;

    AxList(im) = ax ;
end

annotation('textbox', [0 (figH-47.25)/figH 1 44.1/figH], 'String', ...
    sprintf(['反応時間課題バットスイング：踏み込み足 Fz の立ち上がり' ...
             '（%s・新しい除外基準／Go 試行 %d 本）'], GroupLabel, Diag.nGo), ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 15, 'FontWeight', 'bold', 'EdgeColor', 'none') ;

annotation('textbox', [0 (figH-78.75)/figH 1 33.6/figH], 'String', ...
    ['黒い横線 = 条件の中央値（縦線は四分位範囲） / 色つきの折れ線 = 被験者ごとの中央値（色は被験者に対応） / ' ...
     '点 = 個々の試行（被験者ごとに横にずらしてある）   ※ free は自己ペース条件のため参考値（網掛け）'], ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10.5, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;

% ★ 2026-09-18：体重の一覧は BWest から組み立てる。以前は S01〜S05 の値を
%   文字列で直書きしていたので、一部の被験者だけを解析すると脚注だけが
%   別人の値を示していた。
bwText = strjoin( arrayfun(@(k) sprintf('S%02d %.1f', SubjectArray(k), BWest(k)/9.81), ...
                           1:nS, 'UniformOutput', false), '・' ) ;

% 定義の断り書きは下端に置く（上に置くとパネルのタイトルと衝突する）。
% ★ annotation は sprintf の書式を解釈しないので、パーセント記号は %% ではなく % と書く。
annotation('textbox', [0 8/figH 1 245/figH], 'String', ...
    {['RT は 5.6 の定義（Fx がベースライン + 0.20 ×（窓内ピーク − ベース）を 20 ms 超えた時点）。' ...
      '分母は記録末端 0.5 s から推定した体重（' bwText ' kg）'], ...
     ['力の立ち上がり速度 =（Fz2ピーク − Onset 時点の Fz2）÷ 体重 × 100 ÷（Onset → ピーク の秒数）。' ...
      'ピークの探索窓は cue から 2 s（5.7 の g0 と同じ）'], ...
     ['立ち上がり速度 ÷ ピーク力 [1/s] は、達成した力の大きさで割った正規化 RFD。' ...
      'Onset 時点の Fz2 がほぼ 0（踏み込み足が空中）なので、実質 1 ÷（Onset → ピーク の秒数）になる'], ...
     '5指標とも onset が取れた試行だけを使うので n はそろう（2026-09-11 にピークもこの条件に合わせた）', ...
     ['★ 旧図（条件別_全被験者_Fz立ち上がり.png）との違いは除外基準だけ。旧図は BWBase（cue 前の Fz1+Fz2）が' ...
      '被験者内中央値から ±20% ずれる試行を落としていたが、2026-09-10 に撤回した'], ...
     ['撤回の理由：落としていた試行の PeakFz2 分布は残す試行とほぼ同一で（03_Analysis §10.8）、' ...
      '末端でプレートから降りたかどうかはスイング時の計測の妥当性を表さない。除外は床反力の欠損だけにした'], ...
     ['★ もう1つだけ「ピークが接地から 0.5 s 以上離れている試行は落とす」という位置の判定を入れてある（技術説明 §3-7）。' ...
      'S02 gonogo 行13 が該当する1試行で、後続動作の山（1.806 s）がスイングのピーク（0.662 s）を 2.8% 上回って選ばれていた'], ...
     ['値ではなく位置で判定しているのが要点。「1580 ms は長すぎる」と値で切ると、2026-09-10 に廃止した種類の基準に戻ってしまう']}, ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
    'FontSize', 10, 'Color', [0.30 0.30 0.30], 'EdgeColor', 'none') ;


%% ---- 6. 指標ごとの個別 PNG ----

% ★ 高さは上に 0.15 ぶん空ける。パネルのタイトルと中央値の数字は軸の外
%   （normalized で 1.13、データ座標で yHi）に置いてあるので、詰めると切れる。
outDir = fullfile(thisDir, '個別グラフ') ;
if ~isfolder(outDir), mkdir(outDir) ; end

for im = 1:nM
    figOne = figure('Color', 'w', 'Position', [80 80 1150 480], 'Visible', 'off') ;
    axOne  = copyobj(AxList(im), figOne) ;
    set(axOne, 'Position', [0.10 0.10 0.86 0.75]) ;

    onePath = fullfile(outDir, sprintf('%02d_%s%s.png', im, FileName{im}, NameSuffix)) ;
    exportgraphics(figOne, onePath, 'Resolution', 200) ;
    fprintf('出力しました: %s\n', onePath) ;
    close(figOne)
end


%% ---- 7. PNG 出力 ----

% ★ ファイル名は指標名を先頭に置く（2026-09-14）。フォルダを開いたときに
%   何のグラフか一目で分かるようにするため。「新除外基準」は旧基準の図が
%   もう無いので落とした。
outPath = fullfile(thisDir, sprintf('Fz立ち上がり_条件別_%s.png', GroupTag)) ;
exportgraphics(fig, outPath, 'Resolution', 200) ;
fprintf('出力しました: %s\n', outPath) ;
