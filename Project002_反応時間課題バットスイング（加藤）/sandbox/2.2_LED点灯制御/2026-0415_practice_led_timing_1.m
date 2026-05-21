clear;
clc;
close all;

% === ステップ1: 波形ベクトルの作成と確認 ===
% パラメータ
sample_rate  = 1000;    % サンプリングレート [Hz]
ini_duration = 0.1;     % 最初の消灯時間 [秒]
on_duration  = 2.0;     % 点灯時間 [秒]
off_duration = 1.0;     % 終わりの消灯時間 [秒]
voltage_on   = 5.0;     % 点灯電圧 [V]
voltage_off  = 0.0;     % 消灯電圧 [V]

% 波形ベクトルの生成
n_ini = round(ini_duration * sample_rate);
n_on  = round(on_duration  * sample_rate);
n_off = round(off_duration * sample_rate);

waveform = [voltage_off * ones(n_ini,  1);
            voltage_on  * ones(n_on,  1);
            voltage_off * ones(n_off, 1)];

% グラフ描画
tInd = (1:length(waveform)) / sample_rate;
plot(tInd, waveform);
xlabel('Time (s)');
ylabel('Voltage (V)');
title('LED出力波形の確認');
ylim([-1 6]);

% === ステップ2: DAQの初期化と設定 ===
disp('DAQの初期化を行っています...');
dq = daq("ni");
dq.Rate = sample_rate;
addoutput(dq, "Dev1", "ao0", "Voltage");

% === ステップ3: バッファへの書き込みと出力の実行 ===
disp('波形データを送信準備中...');
preload(dq, waveform);

disp('出力を開始します！ LEDに注目してください。');
start(dq, 'Finite');  
disp('出力完了しました。');
