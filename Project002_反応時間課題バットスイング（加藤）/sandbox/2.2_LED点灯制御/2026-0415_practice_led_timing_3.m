clear;
clc;
close all;

% === 例3: ランダムな遅延（ジッター）をもたせた点灯 ===
% --- パラメータ ---
sample_rate  = 10000;
n_trials     = 5;         % 試行回数
on_duration  = 0.3;       % 点灯時間 [秒]
jitter_min   = 1.0;       % 消灯時間（ISI）の最小値 [秒]
jitter_max   = 3.0;       % 消灯時間（ISI）の最大値 [秒]
voltage_on   = 5.0;
voltage_off  = 0.0;

% --- DAQの初期化 ---
disp('DAQの初期化を行っています...');
dq = daq("ni");
dq.Rate = sample_rate;
addoutput(dq, "Dev1", "ao0", "Voltage");

% --- 波形ベクトルの生成（各試行でランダムな時間を生成） ---
disp('ランダムなタイミングを持つ5回分の波形を生成中...');
n_on = round(on_duration * sample_rate);      % 点灯のデータ数（常に一定）

waveform = []; % まず波形を入れる空っぽの箱（配列）を用意します

rand('twister', sum(clock)); % 乱数の種を初期化（毎回違うランダムにするため）

for i = 1:n_trials
    % 1秒〜3秒の間のランダムな時間を生成します
    isi_i  = jitter_min + (jitter_max - jitter_min) * rand();  
    
    % 今回の試行の消灯データ数を計算
    n_off  = round((isi_i - on_duration) * sample_rate);

    fprintf('試行 %d: 点灯までの間隔 = %.3f 秒\n', i, isi_i);

    % 1試行分の波形を作成
    trial_wave = [voltage_on  * ones(n_on,  1);
                  voltage_off * ones(n_off, 1)];
                  
    % これまでに作った波形の後ろに、今回の1試行分をペタッとくっつける
    waveform = [waveform; trial_wave];
end

% グラフ描画で確認
tInd = (1:length(waveform)) / sample_rate;
plot(tInd, waveform);
xlabel('Time (s)');
ylabel('Voltage (V)');
title('LED出力波形（ランダム間隔）の確認');
ylim([-1 6]);

% --- DAQバッファへの書き込みと出力開始 ---
disp('波型データを送信準備中...');
preload(dq, waveform);

disp('出力を開始します！ LEDの「ランダムな点滅」に注目してください。');
start(dq, "Finite");
disp('出力完了しました。');
