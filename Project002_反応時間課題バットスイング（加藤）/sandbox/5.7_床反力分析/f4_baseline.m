% f4_baseline.m
%
% 目的:
%   キュー前の静止区間から体重 BWBase [N] を推定し、
%   被験者中央値から ±20%（Prm.GRF.BWTolerance）外れる試行を
%   計測不良として除外する判定をつくる。
%   BWBase は f6 で Fz を体重正規化する（[BW] 単位にする）ときの分母になる。
%
% 入力:
%   f1_fake_grf.m が作る Data, True
%
% 出力:
%   BWBase   ... 静止時の Fz1 + Fz2 [N]（方式A：キュー前全区間の平均）
%   BWWin    ... 同じものを方式B（キュー直前 0.5 s）で求めた値 [N]。A との一致を見る
%   sdBase1  ... キュー直前 0.5 s の Fz1 の SD [N]（f5 以降で RT 閾値に使う）
%   sdBase2  ... 同じく Fz2 の SD [N]
%   isBad    ... 論理配列。中央値から ±20% 外れた試行が true
%   figure 1 ... ベースライン区間を塗った Fz の時系列
%
% 備考:
%   - ベースライン窓を目的別に2通り取る。方式A（キュー前全区間）を BWBase に、
%     方式B（キュー直前 0.5 s、Prm.RT.BaseSec）をベースライン SD に使う。
%     前者は m3_analyze_single_trial.m:219 と同じ切り出し方。
%   - 除外判定の基準は被験者内の中央値。1試行だけでは妥当性を判定できないので、
%     このスクリプトでは他試行の値を直書きして判定ロジックだけを確かめる。
%   - mean は NaN が1つでもあると全体が NaN になる。実データでは要チェック（f7）。

clear ;
close all

% f1 を先頭で呼ぶ。f1 の中に clear ; close all があるので、
% 先に自分で変数を作っても消される。
f1_fake_grf


%% ---- 1. 必要なものを取り出す（f3 と同じ）----

fsA     = Data.AnalogFs ;        % アナログ系のサンプリング周波数 [Hz]
Fz1_raw = Data.Force1(:, 3) ;    % 後ろ足の鉛直分力 [N]（3列目が Fz、上向き正）
Fz2_raw = Data.Force2(:, 3) ;    % 踏み込み足の鉛直分力 [N]
nSample = numel(Fz1_raw) ;       % 実データは記録長が違うので numel で数える


%% ---- 2. フィルタ（f2 と同じ）----

% butter の第2引数は Hz ではなく、ナイキスト周波数（fsA/2）を 1 とした比。
% ★ /2 を忘れると エラーを出さずに 15 Hz のフィルタになる。
fCut = 30 ;
nOrd = 4 ;
wn   = fCut / (fsA/2) ;

[bF, aF] = butter(nOrd, wn, 'low') ;

% filtfilt は双方向なので位相遅れがゼロ。
Fz1 = filtfilt(bF, aF, Fz1_raw) ;
Fz2 = filtfilt(bF, aF, Fz2_raw) ;


%% ---- 3. キュー時刻と時間軸（f3 と同じ）----

cueThresholdV = 2.5 ;                                              % [V]
tCueAnalog = find( Data.LEDData(:,2) > cueThresholdV, 1, 'first' ) ;

% find は該当なしのときエラーを出さず空配列 [] を返す。
% そのまま進めると何も描かれない図が出るだけで原因が分からないので、ここで止める。
if isempty(tCueAnalog)
    error('f4_baseline:NoCue', 'cue パルスが見つかりません')
end

tRel = ( (1:nSample)' - tCueAnalog ) / fsA ;


%% ---- 4. ベースライン区間を2通り決める ----

% 方式A：キュー前の全区間。体重の推定に使う。
% 点数が多いほどノイズが平均で消えるので、体重のような直流成分の推定に向く。
% m3_analyze_single_trial.m:219 と同じ切り出し方。
baseAll = 1 : tCueAnalog-1 ;

% 方式B：キュー直前 0.5 s。ベースライン SD に使う。
% SD は「動作開始と言える変化量」の基準なので、動作直前の状態だけを見たい。
% 全区間で取ると構え直しの動きまで混ざって SD が過大になる。
baseSec = 0.5 ;                        % Prm.RT.BaseSec に対応
nBase   = round(baseSec * fsA) ;

% ★ max(1, ...) はキューが 0.5 s より前に来る試行の保険。
%   これがないと添字が 0 以下になり Index exceeds ... で止まる。
baseWin = max(1, tCueAnalog - nBase) : tCueAnalog-1 ;


%% ---- 5. 体重推定とベースライン SD ----

% 体重は両足の合計。片足だけ見ると体重にならない。
BWBase = mean(Fz1(baseAll)) + mean(Fz2(baseAll)) ;
BWWin  = mean(Fz1(baseWin)) + mean(Fz2(baseWin)) ;

% SD は足ごとに取る。f5 で RT 閾値（Prm.RT.FzK 倍）の分母になる。
sdBase1 = std(Fz1(baseWin)) ;
sdBase2 = std(Fz2(baseWin)) ;


%% ---- 6. 検算 ----

fprintf('ベースライン区間: 全区間 %d 点 / 0.5 s 窓 %d 点\n', ...
    numel(baseAll), numel(baseWin)) ;

% 擬似データは正解（True.BW）が分かっているので、推定の誤差を直接見られる。
fprintf('BWBase（全区間）= %.1f N（%.2f kg）  正解 %.1f N, 誤差 %+.2f N\n', ...
    BWBase, BWBase/9.81, True.BW, BWBase - True.BW) ;

% 方式A と 方式B が一致することの確認。実データでここが食い違う試行は
% キュー前に動いている（構え直し・体重移動）ということ。
fprintf('BWBase（0.5 s） = %.1f N（%.2f kg）  全区間との差 %+.2f N\n', ...
    BWWin, BWWin/9.81, BWWin - BWBase) ;

% 静止時は後ろ足に全体重、踏み込み足はほぼ 0 N。
% Fz2 が 0 から大きく離れていたら、プレートの割り当てか符号を疑う。
fprintf('内訳: mean Fz1 = %.2f N, mean Fz2 = %.2f N（Fz2 は 0 付近が正常）\n', ...
    mean(Fz1(baseAll)), mean(Fz2(baseAll))) ;

% 10SD を %BW に直しておく。実データでは ≒15 %BW になる想定（parameters.m のコメント）。
% 擬似データはここが小さいので、f5 で閾値の妥当性を確認する必要がある。
fprintf('ベースライン SD: Fz1 = %.3f N, Fz2 = %.3f N（10SD = %.1f N ≒ %.1f %%BW）\n', ...
    sdBase1, sdBase2, 10*sdBase1, 10*sdBase1/BWBase*100) ;


%% ---- 7. 計測不良の除外判定 ----

% 1試行だけでは BWBase の妥当性は判定できない（比べる相手がないため）。
% 判定ロジックを試すために他試行の値を直書きする。
% 255.1 / 378.6 N は実データの実測値（S02_free0002 / S03_free0001）で、
% プレートから足が外れている試行。f7 では同一被験者の全試行から作る。
BWList = [BWBase, 716.1, 700.5, 255.1, 378.6, 730.0] ;

tol = 0.2 ;                            % Prm.GRF.BWTolerance に対応

% ★ 基準は mean ではなく median。
%   上の6試行だと mean 基準は 582.7 N まで引きずられ、許容上限 699.3 N が
%   正常試行（700.5〜730.0 N）を下回るので全6試行が除外される。
%   median 基準（708.3 N）なら不良の2試行だけが落ちる。
%   x7_3_visualize_grf.m:61 が median を使う理由がこれ。
bwRef = median(BWList, 'omitnan') ;

% ★ > tol * bwRef を忘れると エラーにならない。abs(...) は数値だが
%   | は非ゼロを true と扱うので、差がちょうど 0 の試行以外すべて「除外」になる。
isBad = isnan(BWList) | abs(BWList - bwRef) > tol * bwRef ;

fprintf('\n中央値 = %.1f N, 許容範囲 %.1f 〜 %.1f N（±%d%%）\n', ...
    bwRef, (1-tol)*bwRef, (1+tol)*bwRef, tol*100) ;

for k = 1:numel(BWList)
    if isBad(k)
        judge = '除外' ;
    else
        judge = 'OK' ;
    end
    fprintf('  試行 %d: %7.1f N（%5.1f kg） → %s\n', ...
        k, BWList(k), BWList(k)/9.81, judge) ;
end

fprintf('採用 %d / %d 試行\n', sum(~isBad), numel(isBad)) ;

% この判定は体重正規化より前に行う。順序を逆にすると PeakFz / BWBase の
% 割り算で異常な BWBase が分母に入り、比としては一見まともな数字になって
% 不良試行が隠れる。


%% ---- 8. 描画 ----

figure
ax = axes ;

% patch を先に描いて波形を上に重ねる。描画順で後のものが上になる。
% patch は縦方向に軸いっぱいまで塗りたいので、先に y 範囲を決めて使い回す。
yLo = -100 ; yHi = 1600 ;

% 方式A（全区間）を薄い灰色で塗る。
patch([tRel(baseAll(1)) tRel(baseAll(end)) tRel(baseAll(end)) tRel(baseAll(1))], ...
    [yLo yLo yHi yHi], [0.90 0.90 0.90], 'EdgeColor', 'none', ...
    'DisplayName', '全区間') ;
hold on

% 方式B（0.5 s 窓）を上から青みで塗る。全区間の一部であることが見える。
patch([tRel(baseWin(1)) tRel(baseWin(end)) tRel(baseWin(end)) tRel(baseWin(1))], ...
    [yLo yLo yHi yHi], [0.80 0.85 0.95], 'EdgeColor', 'none', ...
    'DisplayName', 'ベースライン（0.5 s）') ;

plot(tRel, Fz1, 'b', 'LineWidth', 1.2, 'DisplayName', 'Fz1 後ろ足') ;
plot(tRel, Fz2, 'r', 'LineWidth', 1.2, 'DisplayName', 'Fz2 踏み込み足') ;

% 合計は静止時に BWBase、動作後もほぼ BWBase に戻る（体重は変わらない）。
plot(tRel, Fz1 + Fz2, 'k:', 'LineWidth', 1.0, 'DisplayName', 'Fz1 + Fz2') ;

yline(BWBase, 'g--', 'BWBase', 'LineWidth', 1.2) ;   % 推定した体重
xline(0, 'k--', 'Cue') ;                             % 時間軸の原点

% 表示範囲は XLim で決める（f3 と同じ理由。技術説明 §3-4）。
set(ax, 'XLim', [-1 2], 'YLim', [yLo yHi])

xlabel('Time from cue [s]')
ylabel('Fz [N]')
legend('Location', 'northwest')
title('ベースライン区間と推定体重')

% 図で確認すること
%   キュー前で Fz1 が BWBase の線に重なり、Fz2 が 0 付近で平坦になっているか。
%   0.5 s 窓（青）が全区間（灰）のキュー直前側の端に収まっているか。
%   Fz1 + Fz2 が動作後に BWBase の線へ戻ってくるか。
