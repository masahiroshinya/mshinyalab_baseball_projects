% f1_fake_grf.m
%
% 目的:
%   床反力分析の練習用に、実データと同じ構造の擬似データをつくる。
%   正解（体重・キュー時刻・反応時間）が分かっている状態でアルゴリズムを検証するため。
%
% 出力（ワークスペースに残す）:
%   Data ... 実データ（x3_DataChecked の DataArray 要素）と同じフィールド構成
%              .AnalogFs  アナログ系のサンプリング周波数 [Hz]
%              .FrameRate マーカー系のサンプリング周波数 [Hz]
%              .Force1    [nSample × 3] 後ろ足の床反力 [N]（3列目が Fz、上向き正）
%              .Force2    [nSample × 3] 踏み込み足の床反力 [N]
%              .LEDData   [nSample × 2] ch1 = ready cue、ch2 = cue（Go は正電圧）
%   True ... 検証用の正解値
%
% 備考:
%   - 生データの Fz は下向き正で記録されているが、load_qualisys_mat.m が反転するため
%     Data.Force1 / Data.Force2 の段階では上向き正になっている。ここでも上向き正でつくる。
%   - キュー前は後ろ足プレートに全体重が乗り、踏み込み足プレートは実質ゼロ
%     （実データで約 -3 N）。踏み込み足はステップ後に初めてプレート2へ着地する。
%     静止時に両足へ配分すると BWBase の意味と Fz2 のベースライン SD が実データと食い違う。

clear ;
close all

%% ---- 1. 時間軸（実データに合わせる）----
fsA     = 1000 ;              % アナログ（床反力・LED）のサンプリング周波数 [Hz]
fs      = 250 ;               % マーカー系のサンプリング周波数 [Hz]
dur     = 5 ;                 % 記録長 [s]
nSample = dur * fsA ;         % 5000

idx = (1:nSample)' ;
t   = (idx - 1) / fsA ;       % 時刻 [s]

%% ---- 2. 正解として決めておく値 ----
tCue   = 2.581 ;              % キュー提示の時刻 [s]（実データと同じ）
rtTrue = 0.25 ;               % 真の反応時間 [s]
tOnset = tCue + rtTrue ;      % 床反力が動き出す時刻 [s]

mass = 73 ;                   % 体重 [kg]（S01 相当）
g    = 9.81 ;
BW   = mass * g ;             % 体重 [N] = 静止時の Fz1 + Fz2

%% ---- 3. Fz 波形をつくる ----
% 後ろ足 Fz1：静止（全体重）→ 踏み込みに向けて少し荷重 → 前足へ移って抜ける
load1 = 0.20 * BW * exp( -(t - (tOnset + 0.20)).^2 / (2*0.10^2) ) ;      % 一時的な荷重増
shift = 0.85 * BW ./ ( 1 + exp( -(t - (tOnset + 0.50)) / 0.06 ) ) ;      % 前足への荷重移動（末端で Fz1+Fz2 = BW に戻す）
Fz1   = BW + load1 - shift ;

% 踏み込み足 Fz2：静止（ゼロ）→ 接地で急増（このピークが解析対象）
land  = 0.85 * BW ./ ( 1 + exp( -(t - (tOnset + 0.30)) / 0.04 ) ) ;      % 着地後の定常荷重
imp   = 0.70 * BW * exp( -(t - (tOnset + 0.35)).^2 / (2*0.06^2) ) ;      % 着地衝撃
Fz2   = land + imp ;

% キュー前は静止させる（ベースラインの SD をノイズだけで決めるため）
isPre      = t < tCue ;
Fz1(isPre) = BW ;
Fz2(isPre) = 0 ;

% 水平2成分はダミー（今回は使わないが実データと列数を揃える）
Fx1 = zeros(nSample, 1) ; Fy1 = zeros(nSample, 1) ;
Fx2 = zeros(nSample, 1) ; Fy2 = zeros(nSample, 1) ;

%% ---- 4. ノイズを足す ----
rng(0)
sdNoise = 3 ;                 % [N]（実データの静止区間と同程度）
Fz1 = Fz1 + sdNoise * randn(nSample, 1) ;
Fz2 = Fz2 + sdNoise * randn(nSample, 1) ;

%% ---- 5. LED（キュー）チャンネルをつくる ----
%   実データの Data.LEDData(:,2) は Go で正のパルスが立つ
led = zeros(nSample, 2) ;
led( t >= tCue - 1.0 & t < tCue - 0.9, 1 ) = 5 ;   % ch1: ready cue
led( t >= tCue       & t < tCue + 0.10, 2 ) = 5 ;   % ch2: go cue（5 V）

%% ---- 6. 実データと同じ構造の Data をつくる ----
Data = struct() ;
Data.AnalogFs  = fsA ;
Data.FrameRate = fs ;
Data.Force1    = [Fx1, Fy1, Fz1] ;   % 後ろ足   [N]（3列目が Fz）
Data.Force2    = [Fx2, Fy2, Fz2] ;   % 踏み込み足 [N]
Data.LEDData   = led ;

%% ---- 7. 検証用の正解 ----
True = struct() ;
True.BW     = BW ;
True.tCue   = tCue ;
True.rtTrue = rtTrue ;
True.tOnset = tOnset ;

fprintf('擬似データ作成: BW = %.1f N（%.1f kg）, tCue = %.3f s, rtTrue = %.3f s\n', ...
    True.BW, mass, True.tCue, True.rtTrue) ;

%% ---- 8. 生波形の確認 ----
figure
ax = axes ;

plot(t, Data.Force1(:,3), 'b', 'LineWidth', 1.0, 'DisplayName', 'Fz1 後ろ足') ;
hold on
plot(t, Data.Force2(:,3), 'r', 'LineWidth', 1.0, 'DisplayName', 'Fz2 踏み込み足') ;
plot(t, Data.Force1(:,3) + Data.Force2(:,3), 'k:', 'DisplayName', 'Fz1 + Fz2') ;

yline(BW, '--', 'Body weight') ;
xline(tCue, 'k--', 'Cue') ;

xlabel('Time [s]')
ylabel('Fz [N]')
legend('Location', 'northwest')
title('擬似床反力データ（生波形）')
