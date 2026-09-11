% i3_plot_example_trials.m
%
% ★ h3_plot_example_trials.m の新しい除外基準版（2026-09-10）。
%   作図コードは h3 と同一で、呼ぶ算出スクリプト（i0）と出力ファイル名だけが違った。
%   比較を済ませたうえで h3 と旧 PNG は削除した（git 履歴から復元できる）。
%   i0 は BWBase 逸脱による除外をやめているので、代表試行に選ばれる試行が
%   h3 と変わることがある（RFD が条件中央値に最も近い試行を選ぶ仕様のため）。
%
% ★ 2026-09-11：MT の区間の終わりを、Fz2 のピークからバット先端のピーク速度に
%   変えた。5.6_プロット の MT（onset → バット先端の最大速度）と定義をそろえる
%   ため。Fz2 のピーク（黒丸）は 5.8 が測っている点なので残してあり、黒丸と
%   青点線の間隔が2つの定義の差にあたる。
%
% 目的:
%   i0 が出した指標が波形のどこを測っているのかを目で確かめる（最小版）。
%   条件ごとに代表の1試行を選び、踏み込み足 Fz2 の時系列に
%   onset の縦線とピークの印を入れる。
%
% 入力:
%   i0_calc_rfd_metrics.m が作る Rec, ConditionNameArray, nC, dataDir, bG/aG
%
% 出力（このスクリプトと同じフォルダ）:
%   代表試行_波形確認_新除外基準.png  ... 全被験者からまとめて代表を選んだ図
%   代表試行_波形確認_S01.png 〜 S05.png ... 被験者ごとに代表を選んだ図
%   ★ 自動では書き出さない。図を見たうえでコマンドウィンドウで y と答えたときだけ
%     出力する。確認は枚数ぶん尋ねず、まとめて1回だけ聞く。
%
% 備考:
%   - ★ 波形は i0 が設計した係数（bG/aG）で作り直す。ここで butter を別に
%     設計するとフィルタが変わり、印の位置と波形がずれて確認にならない。
%   - ★ 末尾 NaN の切り落としも i0 と同じ手順で行う。切り方が違うと
%     サンプル番号が1つずれ、tOnset / tPeak が別の場所を指す。
%   - まずは onset の縦線とピークだけを描く。Fx（RT 検出の根拠）や接地の線は
%     この図で位置関係を確認してから足す。

clear ;
close all

% i0 を先頭で呼ぶ（i1 と同じ。i0 の中に clear があるので順序は変えられない）。
i0_calc_rfd_metrics

% i0 が clear するので、出力先はここで取り直す。
thisDir = fileparts( mfilename('fullpath') ) ;


%% ---- 5. 出力の単位を決める ----

% ★ 2026-09-11：被験者ごとの図も出すようにした。全被験者からまとめて選ぶと、
%   4つのパネルが別々の被験者のものになり（実際 S03/S05/S01/S01 だった）、
%   条件の差を見ているのか個人差を見ているのか分からない。被験者を固定すれば
%   4パネルの違いは条件の違いだけになる。従来の全被験者の図も残す。
%
%   0    ... 全被験者の試行からまとめて選ぶ（従来の図）
%   1〜nS ... その被験者の試行だけから選ぶ

PickSubject = [0, 1:nS] ;

xLim     = [-0.5 1.5] ;     % cue からの表示範囲 [s]
lastSub  = -1 ;             % 読み込み済みの .mat（同じものを何度も読まない）
FigList  = gobjects(0) ;    % 出力する図。★ 全部描いてから、まとめて1回だけ確認する
PathList = {} ;

for ip = 1:numel(PickSubject)

    iPick = PickSubject(ip) ;

    if iPick == 0
        tagText = '全被験者' ;
        outName = '代表試行_波形確認_新除外基準.png' ;
    else
        tagText = sprintf('S%02d', SubjectArray(iPick)) ;
        outName = sprintf('代表試行_波形確認_S%02d.png', SubjectArray(iPick)) ;
    end


    %% ---- 5-1. 代表試行を選ぶ（RFD が条件中央値に最も近い試行）----

    Sel     = Rec([]) ;         % Rec から作ると同じフィールドの空配列になる
    hasAll  = true ;

    for ic = 1:nC
        % ★ MT（バット先端のピーク速度まで）が出ている試行だけから選ぶ。
        %   top マーカーが欠けている試行を選ぶと、橙の帯が描けない。
        isPick = [Rec.ic] == ic & ~isnan([Rec.mtMs]) ;
        if iPick > 0
            isPick = isPick & ([Rec.iS] == iPick) ;
        end
        idx = find(isPick) ;

        % ★ 条件が1つでも空なら、その被験者の図は作らない。空のパネルを
        %   混ぜると、縦軸をそろえた4枚組という図の読み方が崩れる。
        if isempty(idx), hasAll = false ; break, end

        v       = [Rec(idx).rfd] ;
        [~, k]  = min( abs(v - median(v)) ) ;
        Sel(ic) = Rec(idx(k)) ;
    end

    if ~hasAll
        fprintf('%s: 代表試行を選べない条件があるので図を作りません\n', tagText) ;
        continue
    end


    %% ---- 5-2. 波形を用意する（★ 縦軸をそろえるため、描く前に全条件ぶん集める）----

    % パネルごとに自動スケールすると、山の高さを条件間で見比べられない。
    % 4条件を1つの縦軸で描くには、最大値が出そろってからでないと軸を決められない。
    % → 読み込み・フィルタと描画を2つのループに分ける。

    W = struct('tRel',{}, 'z2',{}) ;      % 条件ごとの波形

    for ic = 1:nC

        R = Sel(ic) ;

        % 被験者が変わったときだけ読み直す（同じ .mat を何度も読まない）
        if R.sub ~= lastSub
            load( fullfile(dataDir, sprintf('Data%02d.mat', R.sub)) )
            lastSub = R.sub ;
        end
        D = DataArray(R.it, R.ic) ;

        % --- ★ i0 と同じ前処理（末尾 NaN の切り落とし → 同じ係数でフィルタ）---
        isBad     = any(isnan(D.LEDData),2) | any(isnan(D.Force1),2) | any(isnan(D.Force2),2) ;
        lastValid = find(~isBad, 1, 'last') ;
        F2g       = filtfilt(bG, aG, D.Force2(1:lastValid,:)) ;

        W(ic).tRel = ( (1:size(F2g,1))' - R.tc ) / R.fs ;   % cue を 0 とした時間 [s]
        W(ic).z2   = F2g(:,3) / R.bw * 100 ;                % [%BW]
    end

    % ★ 軸は表示範囲の中の値だけで決める。範囲外まで含めると、
    %   画面に出ていない山に引っ張られて縦軸が無駄に広がる。
    zIn = [] ;
    for ic = 1:nC
        inWin = W(ic).tRel >= xLim(1) & W(ic).tRel <= xLim(2) ;
        zIn   = [zIn ; W(ic).z2(inWin)] ;                                   %#ok<AGROW>
    end
    yLim = [ min(0, min(zIn)) , max(zIn)*1.08 ] ;


    %% ---- 5-3. 描画（1行 × 4条件、縦軸は共通）----

    fig = figure('Color','w', 'Position', [60 80 380*nC 380]) ;

    for ic = 1:nC

        R  = Sel(ic) ;
        ax = subplot(1, nC, ic) ;
        hold(ax, 'on')

        tOn = W(ic).tRel(R.tOnset) ;      % cue からの onset 時刻 [s]
        tPk = W(ic).tRel(R.tPeak)  ;      % cue からの Fz2 ピーク時刻 [s]

        % ★ バット先端のピーク速度の時刻は、onset に MT を足して作る。
        %   マーカー番号から時刻を別に計算すると、帯の長さと i0 が出す MT の値が
        %   数 ms ずれる（マーカー 250 Hz とアナログ 1000 Hz で 1 サンプルの
        %   起点が違うため）。足して作れば、帯の長さ＝MT の値になる。
        tPv = tOn + R.mtMs/1000 ;         % cue からのバット先端ピーク速度の時刻 [s]

        % ★ 区間の塗りは波形より先に描く。後から描くと波形と印を覆ってしまう。
        %   RT = cue → onset、MT = onset → バット先端のピーク速度（5.6 と同じ定義）。
        %   ★ 以前は MT の終わりを Fz2 のピークにしていたが、5.6_プロット と基準を
        %     そろえるためバット先端のピーク速度に変えた（2026-09-11）。
        %   色は薄くする。濃いと波形より塗りが目立ち、確認したいものが見えなくなる。
        patch(ax, [0 tOn tOn 0],       yLim([1 1 2 2]), [0.86 0.91 0.97], 'EdgeColor','none') ;
        patch(ax, [tOn tPv tPv tOn],   yLim([1 1 2 2]), [1.00 0.92 0.83], 'EdgeColor','none') ;

        plot(ax, W(ic).tRel, W(ic).z2, '-', 'Color', [0.80 0.25 0.20], 'LineWidth', 1.4) ;

        % ★ 2本の縦線には必ず別々のラベルを付ける。cue と onset は数百 ms しか
        %   離れていないので、片方だけにラベルを付けると、もう片方の線のラベルに
        %   見えてしまう（実際に「onset に Cue と書いてある」と読めた）。
        %   ★ 縦線のラベルは下、区間のラベルは上に分ける（同じ側に置くと重なる）。
        xline(ax, 0, 'k--', 'Cue', 'LabelHorizontalAlignment','left', ...
            'LabelVerticalAlignment','bottom', 'FontSize', 9) ;
        xline(ax, tOn, '-', 'RT onset', 'Color', [0.85 0.35 0.10], ...
            'LineWidth', 1.4, 'LabelHorizontalAlignment','right', ...
            'LabelVerticalAlignment','bottom', 'FontSize', 9) ;

        % ピークの印（波形より後に描く。先に描くと線に隠れる）。
        % 値は i1 の図と表で読めるので、ここには数値を書かない。
        plot(ax, tPk, W(ic).z2(R.tPeak), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5) ;

        % ★ MT の終わり（バット先端のピーク速度）。黒丸（Fz2 のピーク＝5.8 が測る点）
        %   との間隔が、そのまま2つの MT の定義の違いになる。
        %   ★ ラベルは線の右・上に置く。左に置くと立ち上がりの波形と黒丸に重なる。
        xline(ax, tPv, ':', 'Bat peak vel', 'Color', [0.20 0.35 0.70], ...
            'LineWidth', 1.4, 'LabelHorizontalAlignment','right', ...
            'LabelVerticalAlignment','top', 'FontSize', 9) ;

        set(ax, 'XLim', xLim, 'YLim', yLim, 'FontSize', 10, 'Box','off', 'YGrid','on') ;
        % ★ 被験者ごとの図でも S 番号は残す。図だけ切り出したときに
        %   どの被験者のものか分からなくなるため。
        title(ax, sprintf('%s   S%02d  試行%d', ConditionNameArray{ic}, R.sub, R.it), ...
            'FontSize', 12, 'FontWeight','bold') ;
        xlabel(ax, 'Time from cue [s]') ;
        if ic == 1, ylabel(ax, '踏み込み足Fz2 [%BW]') ; end
    end

    sgtitle(sprintf(['%s   条件別 代表1試行：RT（青）と ' ...
        'MT（橙, onset → バット先端ピーク速度）の区間'], tagText), ...
        'FontSize', 14, 'FontWeight','bold') ;

    FigList(end+1)  = fig ;                                                 %#ok<SAGROW>
    PathList{end+1} = fullfile(thisDir, outName) ;                          %#ok<SAGROW>
end


%% ---- 6. PNG 出力（コマンドウィンドウで確認してから）----

% 実行のたびに自動で書き出すと、図を見る前にファイルが差し替わる。
% ★ drawnow を先に呼ぶ。入力待ちに入る前に図を描き切らせないと、
%   白いままの図を見て y/n を答えることになる。
% ★ 確認は図の枚数ぶん尋ねずに1回だけにする。6回聞かれると読まずに y を
%   押すようになり、確認の意味がなくなる。

drawnow

% ★ h3 は必ず y/n を尋ねていたが、確認が守っているのは「既にある図を
%   見ないまま差し替えてしまうこと」である。ファイルが無いときは失うものが
%   ないので、そのまま書き出す（-batch でも通るようになる）。
isExisting = cellfun(@isfile, PathList) ;
doWrite    = true ;

if any(isExisting)
    fprintf('\n既に出力があります（出力すると上書きになります）:\n') ;
    for k = find(isExisting), fprintf('  %s\n', PathList{k}) ; end

    % y 以外（n・空 Enter を含む）はすべて「出力しない」。取り違えても図が
    % 消えるだけで、ファイルは書き換わらない側に倒しておく。
    reply   = input('図を確認してください。PNG を上書きしますか？ (y/n) : ', 's') ;
    doWrite = strcmpi(strtrim(reply), 'y') ;
end

if doWrite
    for k = 1:numel(FigList)
        exportgraphics(FigList(k), PathList{k}, 'Resolution', 200) ;
        fprintf('出力しました: %s\n', PathList{k}) ;
    end
else
    fprintf('出力しませんでした。図はウィンドウに残っています。\n') ;
end

% 図で確認すること
%   オレンジの縦線（onset）が、Fz2 がまだ 0 付近（踏み込み足が空中）の時点に
%     立っているか。すでに立ち上がった後にあるなら RT が遅れて検出されている。
%   黒丸が波形の最大値に乗っているか。二峰性で1つ目の山を無視していないか。
%   青点線（バット先端のピーク速度）が黒丸より後にあるか。踏み込み足に体重が
%     乗り切ってからバットが最大速度に達するので、通常はこの順になる。
