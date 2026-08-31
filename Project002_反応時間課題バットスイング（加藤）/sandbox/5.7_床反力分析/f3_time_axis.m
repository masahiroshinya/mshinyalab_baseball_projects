% f3_time_axis.m
%
% 目的:
%   LED（cue）チャンネルからキュー時刻をサンプル番号として求め、
%   時間軸をキュー基準（キュー = 0 s）に直す。
%   以降のすべての処理がこの時間軸の上に乗る。
%
% 入力:
%   f1_fake_grf.m が作る Data, True
%
% 出力:
%   tCueAnalog ... キュー提示のサンプル番号（アナログ系）
%   tRel       ... [nSample × 1] キューを 0 とした時刻 [s]
%   figure 1   ... キュー基準で描いた Fz の時系列
%
% 備考:
%   - キュー時刻は「時刻[s]」ではなく「サンプル番号」で持つ。
%     配列の添字にそのまま使えるので、以降の区間指定が単純になる。
%   - 擬似データの cue は正のパルス1本だけ。実データは gonogo の負電圧と
%     gostop の「正の後に負」判定が必要になる（技術説明 §1 f3 の節、f7 で対応）。

clear ;
close all

% f1 を先頭で呼ぶ。f1 の中に clear ; close all があるので、
% 先に自分で変数を作っても消される。
f1_fake_grf


%% ---- 1. 必要なものを取り出す ----

fsA     = Data.AnalogFs ;        % アナログ系のサンプリング周波数 [Hz]
Fz1_raw = Data.Force1(:, 3) ;    % 後ろ足の鉛直分力 [N]（3列目が Fz、上向き正）
Fz2_raw = Data.Force2(:, 3) ;    % 踏み込み足の鉛直分力 [N]

% 要素数は dur*fsA と決め打ちせず numel で数える。
% 実データは試行ごとに記録長が違うので、配列から数えれば f7 でもそのまま動く。
nSample = numel(Fz1_raw) ;


%% ---- 2. フィルタ（f2 と同じ）----

% butter の第2引数は Hz ではなく、ナイキスト周波数（fsA/2）を 1 とした比。
% ★ /2 を忘れると エラーを出さずに 15 Hz のフィルタになる。
fCut = 30 ;
nOrd = 4 ;
wn   = fCut / (fsA/2) ;

[bF, aF] = butter(nOrd, wn, 'low') ;

% filtfilt は双方向なので位相遅れがゼロ。ピークの「時刻」を議論するので filter は使わない。
Fz1 = filtfilt(bF, aF, Fz1_raw) ;
Fz2 = filtfilt(bF, aF, Fz2_raw) ;


%% ---- 3. LED からキュー時刻を求める ----

% LED の出力は 0 V か 5 V なので、中間の 2.5 V を閾値にする。
% 立ち上がりの途中で確実に一度だけ交差するので、ノイズや立ち上がり時間に対して頑健。
% 0.1 V のような低い閾値では暗電流やノイズを拾う危険がある。
cueThresholdV = 2.5 ;                                              % [V]

% ch2 が cue チャンネル。Go では正のパルスが立つ。
%   Data.LEDData(:,2) > cueThresholdV  → 論理配列（5000×1）
%   find(..., 1, 'first')              → 最初に true になった番号だけを返す
% ★ 第2引数の 1 がないと、パルスが立っている 100 サンプル分すべての番号が返る。
%   それを添字に使うと エラーを出さずに 100 本の波形が描かれる。
tCueAnalog = find( Data.LEDData(:,2) > cueThresholdV, 1, 'first' ) ;

% find は該当なしのときエラーを出さず空配列 [] を返す。
% そのまま進めると tRel が空になり、何も描かれない図が出るだけで原因が分からない。
% 実データにはキューが記録されていない試行が実在する
% （x2_import_data.m に Analog data missing の分岐がある）ので、ここで止める。
if isempty(tCueAnalog)
    error('f3_time_axis:NoCue', 'cue パルスが見つかりません')
end


%% ---- 4. キュー基準の時間軸をつくる ----

% f2 の t = ((1:nSample)' - 1)/fsA の「1」を「tCueAnalog」に替えただけ。
% 引く数が原点になるので、キューのサンプル番号を引けばキューが 0 s になる。
tRel = ( (1:nSample)' - tCueAnalog ) / fsA ;


%% ---- 5. 検算 ----

% 誤差 0.0 ms は自動的に出る値ではない。t = (idx-1)/fsA と led(t >= tCue) の
% 関係を正しく扱えていることの確認になる。
fprintf('キュー検出: サンプル番号 %d → 時刻 %.3f s（正解 %.3f s, 誤差 %.1f ms）\n', ...
    tCueAnalog, (tCueAnalog-1)/fsA, True.tCue, ((tCueAnalog-1)/fsA - True.tCue)*1000) ;

% 定義どおりキューが 0 になっているかの直接確認。
fprintf('tRel(tCueAnalog) = %.3f s（0 になるはず）\n', tRel(tCueAnalog)) ;

% 記録長 5 s のうち 2.581 s がキュー前、残りがキュー後。左右非対称が正常。
fprintf('tRel の範囲: %.3f 〜 %.3f s\n', tRel(1), tRel(end)) ;

% 食い違うと plot でエラーになる。
fprintf('tRel の要素数 = %d, Fz1 の要素数 = %d\n', numel(tRel), numel(Fz1)) ;


%% ---- 6. 描画（キュー基準）----

figure
ax = axes ;

plot(tRel, Fz1, 'b', 'LineWidth', 1.2, 'DisplayName', 'Fz1 後ろ足') ;
hold on
plot(tRel, Fz2, 'r', 'LineWidth', 1.2, 'DisplayName', 'Fz2 踏み込み足') ;

xline(0, 'k--', 'Cue') ;                    % 時間軸の原点
xline(True.rtTrue, 'k:', 'Onset (true)') ;  % 正解の動作開始時刻

% 表示範囲は XLim で決める。固定長で切り出すと、データ長が足りない試行が
% すべて除外されて図が空になる（技術説明 §3-4）。
set(ax, 'Xlim', [-1 2])

xlabel('Time from cue [s]')
ylabel('Fz [N]')
legend('Location', 'northwest')
title('キュー基準の時間軸')

% 図で確認すること
%   Fz2 の立ち上がりが Onset (true)（0.25 s）の少し後から始まっているか。
%   Fz1 は 0 s より前は体重で平坦、その後に一度増えて前足へ抜けていく形になる。
