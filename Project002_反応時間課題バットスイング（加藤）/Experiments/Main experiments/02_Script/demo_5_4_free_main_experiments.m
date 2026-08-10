clear;
clc;
close all;

% AO0 ch を、Qualisys のトリガーボックス（NC0）に接続　+5Vを出力することで、Qualisys測定開始
% AO0 ch に、白のLEDを、正負を反転させて接続することで、-5V出力時は白が点灯する（ready cue）
% AO1 ch に、緑のLEDを接続　+5V出力時に緑が点灯する（go cue）
% 自由スイング条件：LEDキュー有り、フォアピリオド固定、CSV不使用

% === パラメータ（他条件と共通） ===
sample_rate            = 1000;
voltage_off            = 0;
voltage_trigOn         = 5.0;
voltage_ready          = -5.0;
voltage_go             = 5.0;

ini_duration           = 0.1;
trig_signal_duration   = 0.1;

trig_to_ready_interval = 1.0;   % 初期位置計測用（Qualisys開始後の静止期間）
ready_signal_duration  = 0.5;
gonogo_signal_duration = 0.5;
off_duration           = 0.1;
swing_max_duration     = 5.0;

% === 自由スイング固有パラメータ ===
foreperiod_fix = 1.5;   % 固定フォアピリオド [秒]（大学・社会人投手の振りかぶり開始〜リリースの中央値）

ini_s           = round(ini_duration           * sample_rate) ;
trig_s          = round(trig_signal_duration   * sample_rate) ;
trig_to_ready_s = round(trig_to_ready_interval * sample_rate) ;
ready_s         = round(ready_signal_duration  * sample_rate) ;
gonogo_s        = round(gonogo_signal_duration * sample_rate) ;
off_s           = round(off_duration           * sample_rate) ;
fp_s            = round(foreperiod_fix         * sample_rate) ;

nTrial = 15;

%% DAQの初期化と設定
disp('DAQの初期化を行っています...');
dq = daq("ni");
dq.Rate = sample_rate;
addoutput(dq, "Dev1", {'ao0', 'ao1'}, "Voltage");

try
for iTrial = 1:nTrial

    fprintf('%d試行目 (自由スイング, Foreperiod=%.1fs)\n', iTrial, foreperiod_fix);

    if foreperiod_fix <= ready_signal_duration
        error('foreperiod_fix（%.1fs）はready_signal_duration（%.1fs）より大きくする必要があります。', ...
            foreperiod_fix, ready_signal_duration);
    end

    % 波形ベクトルの生成 AO0
   waveform0 = [voltage_off    * ones(ini_s, 1); ...
                voltage_trigOn * ones(trig_s, 1); ...
                voltage_off    * ones(trig_to_ready_s, 1); ...
                voltage_ready  * ones(ready_s, 1); ...
                voltage_off    * ones(fp_s - ready_s + gonogo_s + off_s, 1)] ;

   waveform1 = [voltage_off * ones(ini_s + trig_s + trig_to_ready_s + fp_s, 1); ...
                voltage_go  * ones(gonogo_s, 1); ...
                voltage_off * ones(off_s, 1)] ;


    waveform = [waveform0, waveform1];

    input(sprintf('[試行 %d/%d] Qualisysをcapture待機状態にし、準備ができたらEnterを押してください...', iTrial, nTrial));
    for iCount = 4:-1:1
        fprintf('  %d 秒後に開始...\n', iCount);
        pause(1);
    end
    fprintf('  → 試行開始\n');

    preload(dq, waveform);
    start(dq, 'Finite');
    waveform_duration = ini_duration + trig_signal_duration + trig_to_ready_interval + ...
                        foreperiod_fix + gonogo_signal_duration + off_duration;
    pause(waveform_duration);
    stop(dq);

    fprintf('  スイング完了待機中 (%.0f秒)...\n', swing_max_duration);
    pause(swing_max_duration);
    fprintf('  → 次の試行に進んでください\n');

end

catch ME
    write(dq, [0, 0]);
    rethrow(ME);
end
