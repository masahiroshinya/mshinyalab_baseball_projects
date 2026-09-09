n% h3_plot_example_trials.m
%
% 目的:
%   h0 が出した指標が波形のどこを測っているのかを目で確かめる（最小版）。
%   条件ごとに代表の1試行を選び、踏み込み足 Fz2 の時系列に
%   onset の縦線とピークの印だけを入れる。
%
% 入力:
%   h0_calc_rfd_metrics.m が作る Rec, ConditionNameArray, nC, dataDir, bG/aG
%
% 出力:
%   代表試行_波形確認.png（このスクリプトと同じフォルダ）
%   ★ 自動では書き出さない。図を見たうえでコマンドウィンドウで y と答えたときだけ出力する。
%
% 備考:
%   - ★ 波形は h0 が設計した係数（bG/aG）で作り直す。ここで butter を別に
%     設計するとフィルタが変わり、印の位置と波形がずれて確認にならない。
%   - ★ 末尾 NaN の切り落としも h0 と同じ手順で行う。切り方が違うと
%     サンプル番号が1つずれ、tOnset / tPeak が別の場所を指す。
%   - まずは onset の縦線とピークだけを描く。Fx（RT 検出の根拠）や接地の線は
%     この図で位置関係を確認してから足す。

clear ;
close all

% h0 を先頭で呼ぶ（h1 と同じ。h0 の中に clear があるので順序は変えられない）。
h0_calc_rfd_metrics

% h0 が clear するので、出力先はここで取り直す。
thisDir = fileparts( mfilename('fullpath') ) ;


%% ---- 5. 代表試行を選ぶ（RFD が条件中央値に最も近い試行）----

Sel = Rec([]) ;                           % Rec から作ると同じフィールドの空配列になる

for ic = 1:nC
    idx     = find([Rec.ic] == ic) ;
    v       = [Rec(idx).rfd] ;
    [~, k]  = min( abs(v - median(v)) ) ;
    Sel(ic) = Rec(idx(k)) ;
end


%% ---- 6. 波形を用意する（★ 縦軸をそろえるため、描く前に全条件ぶん集める）----

% パネルごとに自動スケールすると、山の高さを条件間で見比べられない。
% 4条件を1つの縦軸で描くには、最大値が出そろってからでないと軸を決められない。
% → 読み込み・フィルタと描画を2つのループに分ける。

xLim    = [-0.5 1.5] ;                    % cue からの表示範囲 [s]
W       = struct('tRel',{}, 'z2',{}) ;    % 条件ごとの波形
lastSub = -1 ;

for ic = 1:nC

    R = Sel(ic) ;

    % 被験者が変わったときだけ読み直す（同じ .mat を何度も読まない）
    if R.sub ~= lastSub
        load( fullfile(dataDir, sprintf('Data%02d.mat', R.sub)) )
        lastSub = R.sub ;
    end
    D = DataArray(R.it, R.ic) ;

    % --- ★ h0 と同じ前処理（末尾 NaN の切り落とし → 同じ係数でフィルタ）---
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
    zIn   = [zIn ; W(ic).z2(inWin)] ;                                       %#ok<AGROW>
end
yLim = [ min(0, min(zIn)) , max(zIn)*1.08 ] ;


%% ---- 7. 描画（1行 × 4条件、縦軸は共通）----

fig = figure('Color','w', 'Position', [60 80 380*nC 380]) ;

for ic = 1:nC

    R  = Sel(ic) ;
    ax = subplot(1, nC, ic) ;
    hold(ax, 'on')

    tOn = W(ic).tRel(R.tOnset) ;      % cue からの onset 時刻 [s]
    tPk = W(ic).tRel(R.tPeak)  ;      % cue からの Fz2 ピーク時刻 [s]

    % ★ 区間の塗りは波形より先に描く。後から描くと波形と印を覆ってしまう。
    %   RT = cue → onset、MT = onset → Fz2 ピーク（h0 の指標3）。
    %   色は薄くする。濃いと波形より塗りが目立ち、確認したいものが見えなくなる。
    patch(ax, [0 tOn tOn 0],       yLim([1 1 2 2]), [0.86 0.91 0.97], 'EdgeColor','none') ;
    patch(ax, [tOn tPk tPk tOn],   yLim([1 1 2 2]), [1.00 0.92 0.83], 'EdgeColor','none') ;

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
    % 値は h1 の図と表で読めるので、ここには数値を書かない。
    plot(ax, tPk, W(ic).z2(R.tPeak), 'ko', 'MarkerSize', 8, 'LineWidth', 1.5) ;

    set(ax, 'XLim', xLim, 'YLim', yLim, 'FontSize', 10, 'Box','off', 'YGrid','on') ;
    title(ax, sprintf('%s   S%02d  試行%d', ConditionNameArray{ic}, R.sub, R.it), ...
        'FontSize', 12, 'FontWeight','bold') ;
    xlabel(ax, 'Time from cue [s]') ;
    if ic == 1, ylabel(ax, 'Fz2 踏み込み足 [%BW]') ; end
end

sgtitle('条件別 代表1試行：RT（青）と MT（橙）の区間', 'FontSize', 14, 'FontWeight','bold') ;


%% ---- 8. PNG 出力（コマンドウィンドウで確認してから）----

% 実行のたびに自動で書き出すと、図を見る前にファイルが差し替わる。
% ★ drawnow を先に呼ぶ。入力待ちに入る前に図を描き切らせないと、
%   白いままの図を見て y/n を答えることになる。

outPath = fullfile(thisDir, '代表試行_波形確認.png') ;

drawnow

if isfile(outPath)
    fprintf('\n既に出力があります（出力すると上書きになります）: %s\n', outPath) ;
end

% y 以外（n・空 Enter を含む）はすべて「出力しない」。取り違えても図が
% 消えるだけで、ファイルは書き換わらない側に倒しておく。
reply = input('図を確認してください。PNG を出力しますか？ (y/n) : ', 's') ;

if strcmpi(strtrim(reply), 'y')
    exportgraphics(fig, outPath, 'Resolution', 200) ;
    fprintf('出力しました: %s\n', outPath) ;
else
    fprintf('出力しませんでした。図はウィンドウに残っています。\n') ;
end

% 図で確認すること
%   オレンジの縦線（onset）が、Fz2 がまだ 0 付近（踏み込み足が空中）の時点に
%     立っているか。すでに立ち上がった後にあるなら RT が遅れて検出されている。
%   黒丸が波形の最大値に乗っているか。二峰性で1つ目の山を無視していないか。
