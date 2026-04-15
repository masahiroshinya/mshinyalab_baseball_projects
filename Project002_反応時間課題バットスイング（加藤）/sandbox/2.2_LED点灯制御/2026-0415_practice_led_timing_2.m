clear;
clc;
close all;

% === 例2: 繰り返し点滅させる（全波形を事前生成） ===
% --- パラメータ ---
sample_rate  = 10000;
n_trials     = 5;       % 繰り返す回数 今回は5回
on_duration  = 0.3;     % 点灯時間 [秒]
isi          = 1.5;     % 刺激間隔（点灯開始から次の点灯開始まで）[秒]
voltage_on   = 5.0;
voltage_off  = 0.0;

% --- DAQの初期化 ---
disp('DAQの初期化を行っています...');
dq = daq("ni");
dq.Rate = sample_rate;
addoutput(dq, "Dev1", "ao0", "Voltage");

% --- 波形ベクトルの生成（全試行分を連結） ---
disp('全5回分の波形を生成中...');
n_on  = round(on_duration * sample_rate);
n_off = round((isi - on_duration) * sample_rate);  % 1試行あたりの消灯サンプル数

% まず「1回分（点灯0.3秒＋消灯1.2秒）」の波形を作る
single_trial = [voltage_on  * ones(n_on,  1);
                voltage_off * ones(n_off, 1)];

% repmat関数を使って、1回分の波形を縦に5回分(n_trials回)繰り返した長い波形を作る
waveform = repmat(single_trial, n_trials, 1);

% グラフ描画で確認
tInd = (1:length(waveform)) / sample_rate;
plot(tInd, waveform);
xlabel('Time (s)');
ylabel('Voltage (V)');
title('LED出力波形（5回繰り返し）の確認');
ylim([-1 6]);

% --- DAQバッファへの書き込みと出力開始 ---
disp('波型データを送信準備中...');
preload(dq, waveform);

disp('出力を開始します！ LEDの5回の点滅に注目してください。');
start(dq, "Finite");
disp('出力完了しました。');
