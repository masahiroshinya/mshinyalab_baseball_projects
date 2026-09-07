% f5_peak.m
%
% 目的:
%   キュー起点の探索窓（2 s）の中で Fz のピーク値と、その時刻を求める。
%   max の第2出力は「スライス内の番号」なので、絶対サンプル番号に直すのが山場。
%
% 入力:
%   f1_fake_grf.m が作る Data, True
%
% 出力:
%   swingRange       ... ピークを探すサンプル番号の並び（キュー 〜 キュー+2 s）
%   PeakFz1/PeakFz2  ... 窓内の最大 Fz [N]（後ろ足／踏み込み足）
%   iPeak1/iPeak2    ... ピークの絶対サンプル番号
%   tPeak1/tPeak2    ... ピークの時刻 [s]（キュー基準）
%   figure 1         ... 探索窓を塗り、ピークに印を付けた Fz の時系列
%
% 備考:
%   - 探索窓は Prm.GRF.WinSec = 2.0（キュー起点）。m3_analyze_single_trial.m:222-226 と同じ。
%   - 窓の終わりは min で配列長に抑える。記録が 2 s に届かない試行で添字が範囲外になる。
%   - max の第2出力の変換を忘れると エラーを出さずにピーク時刻だけがずれる（技術説明 §3-3）。

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
    error('f5_peak:NoCue', 'cue パルスが見つかりません')
end

tRel = ( (1:nSample)' - tCueAnalog ) / fsA ;

%% ---- 4. ベースライン（f4 の方式A のみ）----

% f6 で %BW に直すときの分母。f5 では検算の単位換算に使う。
baseAll = 1 : tCueAnalog-1 ;
BWBase  = mean(Fz1(baseAll)) + mean(Fz2(baseAll)) ;

%% ---- 5. ピークの探索窓 ----
winSec = 2.0 ;
swingEnd = min( tCueAnalog + round(winSec*fsA), nSample ) ;
swingRange = tCueAnalog : swingEnd ;

%% ---- 6. ピークを取る ----
[PeakFz1, i1] = max( Fz1(swingRange)) ;
iPeak1 = swingRange(1) + i1 -1 ;

[PeakFz2, i2] = max( Fz2(swingRange)) ;
iPeak2 = swingRange(1) + i2 -1 ;

tPeak1 = tRel(iPeak1) ;
tPeak2 = tRel(iPeak2) ;

%% ---- 7. 検算 ----
fprintf('探索窓: サンプル %d 〜 %d（%d 点, %.3f 〜 %.3f s）\n', ...
    swingRange(1), swingRange(end), numel(swingRange), ...
    tRel(swingRange(1)), tRel(swingRange(end))) ;

fprintf('PeakFz1 = %.1f N（%.3f BW）@ %.3f s\n', PeakFz1, PeakFz1/BWBase, tPeak1) ;
fprintf('PeakFz2 = %.1f N（%.3f BW）@ %.3f s\n', PeakFz2, PeakFz2/BWBase, tPeak2) ;

% 変換を忘れた場合との比較（学習用。時刻が負になるのが症状）
fprintf('（変換前の番号で読むと %.3f s。%.3f s 手前にずれる）\n', ...
    tRel(i1), tPeak1 - tRel(i1)) ;

% ピークが窓の端に来ていないかの確認。端なら窓が短すぎて本当の山を切っている。
fprintf('窓内の位置: Fz1 %.1f %%, Fz2 %.1f %%（0 %% や 100 %% は窓が不適切）\n', ...
    i1/numel(swingRange)*100, i2/numel(swingRange)*100) ;

%% ---- 8. 描画 ----

figure
ax = axes ;

% patch を先に描いて波形を上に重ねる。描画順で後のものが上になる。
% patch は縦方向に軸いっぱいまで塗りたいので、先に y 範囲を決めて使い回す。
yLo = -100 ; yHi = 1600 ;

% 探索窓を薄い黄色で塗る。ピークがこの中に収まっていることを目で見る。
% 窓の端に張り付いていたら、窓が短すぎて本当の山を切っている。
patch([tRel(swingRange(1)) tRel(swingRange(end)) tRel(swingRange(end)) tRel(swingRange(1))], ...
    [yLo yLo yHi yHi], [1.00 0.95 0.80], 'EdgeColor', 'none', ...
    'DisplayName', '探索窓（2 s）') ;
hold on

plot(tRel, Fz1, 'b', 'LineWidth', 1.2, 'DisplayName', 'Fz1 後ろ足') ;
plot(tRel, Fz2, 'r', 'LineWidth', 1.2, 'DisplayName', 'Fz2 踏み込み足') ;

% 合計は静止時に BWBase、動作後もほぼ BWBase に戻る（体重は変わらない）。
plot(tRel, Fz1 + Fz2, 'k:', 'LineWidth', 1.0, 'DisplayName', 'Fz1 + Fz2') ;

% ピークの印は波形より後に描く。先に描くと後から重なる線に隠れる。
% DisplayName を付けないと凡例に data1 のような自動名が入る。
plot(tPeak1, PeakFz1, 'bo', 'MarkerSize', 8, 'LineWidth', 1.5, 'DisplayName', 'PeakFz1') ;
plot(tPeak2, PeakFz2, 'ro', 'MarkerSize', 8, 'LineWidth', 1.5, 'DisplayName', 'PeakFz2') ;

yline(BWBase, 'g--', 'BWBase', 'LineWidth', 1.2) ;   % 推定した体重
xline(0, 'k--', 'Cue') ;                             % 時間軸の原点

% 表示範囲は XLim で決める（f3 と同じ理由。技術説明 §3-4）。
set(ax, 'XLim', [-1 2], 'YLim', [yLo yHi])

xlabel('Time from cue [s]')
ylabel('Fz [N]')
legend('Location', 'northwest')
title('ピーク Fz と探索窓')

% 図で確認すること
%   印が波形の頂点に乗っているか（ずれていたら第2出力の変換を間違えている）。
%   印が塗った窓の内側にあり、窓の端に張り付いていないか。
%   Fz2（踏み込み足）の印のほうが Fz1 より高く、かつ後の時刻にあるか。
