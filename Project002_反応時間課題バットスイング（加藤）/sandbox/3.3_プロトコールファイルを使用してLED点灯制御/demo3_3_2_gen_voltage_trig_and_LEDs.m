clear;
clc;
close all;

% AO0 ch を、Qualisys のトリガーボックス（NC0）に接続　+5Vを出力することで、Qualisys測定開始
% AO0 ch に、白のLEDを、正負を反転させて接続することで、-5V出力時は白が点灯する（ready cue)
% AO1 ch に、緑と赤のLEDを、正負を反転させて接続することで、+5V出力時は緑、-5V出力時は赤が点灯する


% === ステップ1: 波形ベクトルの作成と確認 ===
% パラメータ：　全試行共通
sample_rate  = 1000;    % サンプリングレート [Hz]
voltage_off = 0 ;
voltage_trigOn = 5.0 ;
voltage_ready = -5.0 ;
voltage_go = 5.0 ;
voltage_nogo = -5.0 ;

ini_duration = 0.1;     % 最初の消灯時間 [秒]
trig_signal_duration = 0.1 ;
trig_to_ready_interval = 1.0 ;
ready_signal_duration = 0.5 ;
gonogo_signal_duration = 0.5 ;
off_duration = 0.1 ;

% パラメータ：　試行ごとに異なる
forepriod = 2.0 ; % ready cue to go/nogo cue 
cue_text = "go" ; % go / nogo

%%
switch cue_text
    case "go"
        voltage_ao1 = voltage_go ;
    case "nogo"
        voltage_ao1 = voltage_nogo ;
end


% 波形ベクトルの生成 AO0
waveform0 = [voltage_off * ones(ini_duration * sample_rate,  1);... % 最初のゼロ
             voltage_trigOn * ones(trig_signal_duration * sample_rate,  1);... % Qualisysへのトリガー
             voltage_off * ones(trig_to_ready_interval * sample_rate,  1);... % トリガーからreadyまで
             voltage_ready * ones(ready_signal_duration * sample_rate,  1);... % ready
             voltage_off * ones((forepriod - ready_signal_duration + gonogo_signal_duration + off_duration) * sample_rate,  1)] ; % 残り
             
waveform1 = [voltage_off * ones((ini_duration + trig_signal_duration + trig_to_ready_interval + forepriod) * sample_rate,  1);... % 最初のゼロ
             voltage_ao1 * ones(gonogo_signal_duration * sample_rate,  1);... % Qualisysへのトリガー
             voltage_off * ones(off_duration * sample_rate,  1)] ;   % 残り

waveform = [waveform0, waveform1] ;

% グラフ描画
tInd = (1:length(waveform)) / sample_rate;
plot(tInd, waveform);
xlabel('Time (s)');
ylabel('Voltage (V)');
title('LED出力波形の確認');
ylim([-6, 6]);

% === ステップ2: DAQの初期化と設定 ===
disp('DAQの初期化を行っています...');
dq = daq("ni");
dq.Rate = sample_rate;
addoutput(dq, "Dev1", {'ao0', 'ao1'}, "Voltage");

% === ステップ3: バッファへの書き込みと出力の実行 ===
disp('波形データを送信準備中...');
preload(dq, waveform);

disp('出力を開始します！ LEDに注目してください。');
start(dq, 'Finite');  
disp('出力完了しました。');
