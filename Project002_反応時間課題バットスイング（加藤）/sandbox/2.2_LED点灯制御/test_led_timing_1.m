

% --- パラメータ ---
sample_rate  = 1000;   % サンプリングレート [Hz]（1ms分解能）
ini_duration = 0.1;     % 消灯時間 [秒]（電圧値を初期化）
on_duration  = 2.0;     % 点灯時間 [秒]
off_duration = 1.0;     % 消灯時間 [秒]（波形終端を0Vにするためのパディング）
voltage_on   = 5.0;     % 点灯電圧 [V]
voltage_off  = 0.0;     % 消灯電圧 [V]

% --- 波形ベクトルの生成 ---
n_ini = round(ini_duration * sample_rate);  % 消灯サンプル数
n_on  = round(on_duration  * sample_rate);  % 点灯サンプル数
n_off = round(off_duration * sample_rate);  % 消灯サンプル数

waveform = [voltage_off * ones(n_ini,  1);
            voltage_on  * ones(n_on,  1);
            voltage_off * ones(n_off, 1)];
tInd = [1:length(waveform)] / sample_rate ;
plot(waveform)

% --- DAQの初期化 ---
dq = daq("ni");
dq.Rate = sample_rate;
addoutput(dq, "Dev1", "ao0", "Voltage");


% --- DAQバッファへの書き込み ---
preload(dq, waveform);

% --- 出力開始 ---
start(dq, 'Finite');  % 波形を全出力して自動停止


