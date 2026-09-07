% f6_plot.m
%
% 目的:
%   Fz を体重 BWBase で割って [BW] 単位に直し、時系列とピークを図にする。
%   実データの被験者の体重は 60〜88 kg に散らばるので、N のままでは
%   被験者間・条件間の比較ができない。1.0 BW は「静止して立っている力」という
%   誰にとっても同じ意味を持つ基準になる。
%
% 入力:
%   f1_fake_grf.m が作る Data, True
%
% 出力:
%   Fz1n / Fz2n         ... 体重正規化した Fz の時系列 [BW]
%   PeakFz1n / PeakFz2n ... 正規化したピーク値 [BW]
%   figure 1            ... 2段 subplot（上＝後ろ足、下＝踏み込み足）
%
% 備考:
%   - 単位は [BW]（%BW ではない）。参照実装 x7_3_visualize_grf.m:212-213 に合わせる。
%   - BWBase は正の定数なので、割っても大小関係は変わらない。
%     → ピークのサンプル番号は f5 で取ったものがそのまま使える（取り直さない）。
%   - 実データでは BWBase が NaN や 0 に近い試行がある。0 で割ると
%     エラーを出さずに Inf になり、YLim の外へ飛んで「線が消えた図」になる。
%     f4 の isBad で割る前に落とすのが正しい順序（f7 で対応）。

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
    error('f6_plot:NoCue', 'cue パルスが見つかりません')
end

tRel = ( (1:nSample)' - tCueAnalog ) / fsA ;


%% ---- 4. ベースライン（f4 の方式A のみ）----

% ここで [BW] に直すときの分母になる。
baseAll = 1 : tCueAnalog-1 ;
BWBase  = mean(Fz1(baseAll)) + mean(Fz2(baseAll)) ;


%% ---- 5. ピークの探索窓（f5 と同じ）----

winSec = 2.0 ;                         % Prm.GRF.WinSec

% ★ min で配列長に抑えるのが必須（技術説明 §3-4）。
swingEnd   = min( tCueAnalog + round(winSec*fsA), nSample ) ;
swingRange = tCueAnalog : swingEnd ;


%% ---- 6. ピークを取る（f5 と同じ）----

% max の第2出力は「スライス内の番号」。絶対サンプル番号に直す（技術説明 §3-3）。
[PeakFz1, i1] = max( Fz1(swingRange) ) ;
iPeak1 = swingRange(1) + i1 - 1 ;

[PeakFz2, i2] = max( Fz2(swingRange) ) ;
iPeak2 = swingRange(1) + i2 - 1 ;

tPeak1 = tRel(iPeak1) ;
tPeak2 = tRel(iPeak2) ;


%% ---- 7. 体重正規化 ----

% BWBase は正の定数なので、全部の点を同じ数で割っても大小関係は変わらない。
% → ピークの番号・時刻は f5 で取ったものがそのまま使える。取り直す必要はない。
%   参照実装 x7_3_visualize_grf.m が m3 の PeakFz1 を割るだけで済ませているのも同じ理由。
Fz1n = Fz1 / BWBase ;                  % [BW]
Fz2n = Fz2 / BWBase ;

PeakFz1n = PeakFz1 / BWBase ;
PeakFz2n = PeakFz2 / BWBase ;


%% ---- 8. 検算 ----

fprintf('BWBase = %.1f N（%.2f kg）→ 1.000 BW\n', BWBase, BWBase/9.81) ;
fprintf('PeakFz1 = %.1f N → %.3f BW\n', PeakFz1, PeakFz1n) ;
fprintf('PeakFz2 = %.1f N → %.3f BW\n', PeakFz2, PeakFz2n) ;

% 正規化後に max を取り直しても同じ番号になるはず（定数で割っただけなので）。
% 番号が変わったらどこかで間違えている。
[chk1, j1] = max(Fz1n(swingRange)) ;
[chk2, j2] = max(Fz2n(swingRange)) ;
fprintf('順序不変の確認: 番号 Fz1 %d/%d, Fz2 %d/%d, 値の差 %.1e / %.1e BW\n', ...
    j1, i1, j2, i2, chk1 - PeakFz1n, chk2 - PeakFz2n) ;

% 正規化の定義そのものの確認。静止区間の合計は必ず 1.000 BW になる。
% ここがずれたら分母（BWBase）か窓（baseAll）を間違えている。
fprintf('静止区間の合計 = %.6f BW（1.000000 になるはず）\n', ...
    mean(Fz1n(baseAll)) + mean(Fz2n(baseAll))) ;

% キュー前は後ろ足に全体重、踏み込み足はほぼ 0（f1 の設計）。
fprintf('  内訳: Fz1n = %.4f BW, Fz2n = %.4f BW\n', ...
    mean(Fz1n(baseAll)), mean(Fz2n(baseAll))) ;

% 動作後も体重は変わらないので、合計は 1 BW 付近へ戻る。
% 1.0 から離れるなら f1 の shift 振幅が合っていない。
fprintf('末端 100 点の合計 = %.4f BW\n', ...
    mean(Fz1n(end-99:end) + Fz2n(end-99:end))) ;


%% ---- 9. 描画（2段 subplot）----

% 参照実装 x7_3_visualize_grf.m:41-42 と同じ軸範囲にする。
plotRange = [-1 2] ;                   % 表示範囲 [s]（f3 と同じ理由で XLim で決める）
YLimBW    = [-0.1 1.6] ;               % 縦軸 [BW]（上下段で共通）

% 後ろ足は 1.0 → 1.2 → 0 と下がり、踏み込み足は 0 → 1.4 と上がる。
% 形も向きも違うので重ね描きすると読めない。参照実装と同じく上下2段に分ける。
%
% 2枚で描く中身は同じなので、構造体配列にまとめてループで回す。
% f5 では f4 の図をコピーしてタイトルが残る事故が起きた。同じ描画は2回書かない。
Plate(1).Fz = Fz1n ; Plate(1).Peak = PeakFz1n ; Plate(1).tPeak = tPeak1 ;
Plate(1).Name = 'プレート1（後ろ足）' ;      Plate(1).Color = 'b' ;

Plate(2).Fz = Fz2n ; Plate(2).Peak = PeakFz2n ; Plate(2).tPeak = tPeak2 ;
Plate(2).Name = 'プレート2（踏み込み足）' ;  Plate(2).Color = 'r' ;

figure
for k = 1:2

    subplot(2, 1, k)

    % ★ subplot はすでに軸を作っているので gca で受け取る。
    %   ここで ax = axes と書くと新しい軸が上に重なって subplot を潰す。
    ax = gca ;

    % 探索窓。patch は縦方向に軸いっぱいまで塗るので YLimBW を使い回す。
    patch([tRel(swingRange(1)) tRel(swingRange(end)) tRel(swingRange(end)) tRel(swingRange(1))], ...
        [YLimBW(1) YLimBW(1) YLimBW(2) YLimBW(2)], [1.00 0.95 0.80], ...
        'EdgeColor', 'none', 'DisplayName', '探索窓（2 s）') ;
    hold on

    plot(tRel, Plate(k).Fz, Plate(k).Color, 'LineWidth', 1.2, ...
        'DisplayName', Plate(k).Name) ;

    % 印は波形より後に描く（先に描くと線に隠れる）。
    plot(Plate(k).tPeak, Plate(k).Peak, 'ko', 'MarkerSize', 8, 'LineWidth', 1.5, ...
        'DisplayName', 'Peak') ;

    % 数値を図に書き込む。先頭の空白2つは印との間隔。
    text(Plate(k).tPeak, Plate(k).Peak, ...
        sprintf('  %.3f BW @ %.3f s', Plate(k).Peak, Plate(k).tPeak), ...
        'VerticalAlignment', 'bottom') ;

    % 正規化したので体重は必ず 1.0。この線に静止区間が乗るのが正しい。
    yline(1, 'g--', '1 BW', 'LineWidth', 1.2) ;
    xline(0, 'k--', 'Cue') ;

    set(ax, 'XLim', plotRange, 'YLim', YLimBW)
    xlabel('Time from cue [s]')
    ylabel('Fz [BW]')
    legend('Location', 'northwest')
    title(Plate(k).Name)
    grid on

end

sgtitle('体重正規化した Fz の時系列とピーク')

% 図で確認すること
%   上段の静止区間（キューより左）が緑の 1 BW 線にぴったり乗っているか。
%     これが正規化ができている一番分かりやすい証拠。
%   下段の静止区間が 0 付近で平坦か（踏み込み足はまだプレートに乗っていない）。
%   印とラベルの数値が波形の頂点に一致しているか。
%   両段のピークが探索窓（黄）の内側にあり、窓の端に張り付いていないか。
