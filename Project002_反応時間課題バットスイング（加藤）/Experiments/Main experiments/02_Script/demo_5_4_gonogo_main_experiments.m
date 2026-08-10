clear;
clc;
close all;

% AO0 ch を、Qualisys のトリガーボックス（NC0）に接続　+5Vを出力することで、Qualisys測定開始
% AO0 ch に、白のLEDを、正負を反転させて接続することで、-5V出力時は白が点灯する（ready cue)
% AO1 ch に、緑と赤のLEDを、正負を反転させて接続することで、+5V出力時は緑、-5V出力時は赤が点灯する


% === ステップ1: 波形ベクトルの作成と確認 ===
% パラメータ：　全試行共通
sample_rate  = 1000;
voltage_off = 0 ;
voltage_trigOn = 5.0 ;
voltage_ready = -5.0 ;
voltage_go = 5.0 ;
voltage_nogo = -5.0 ;

ini_duration = 0.1;
trig_signal_duration = 0.1 ;
trig_to_ready_interval = 1.0 ;
ready_signal_duration = 0.5 ;
gonogo_signal_duration = 0.5 ;
off_duration = 0.1 ;
swing_max_duration = 5.0 ;

% サンプル数を事前に整数として計算
ini_s           = round(ini_duration           * sample_rate) ;
trig_s          = round(trig_signal_duration   * sample_rate) ;
trig_to_ready_s = round(trig_to_ready_interval * sample_rate) ;
ready_s         = round(ready_signal_duration  * sample_rate) ;
gonogo_s        = round(gonogo_signal_duration * sample_rate) ;
off_s           = round(off_duration           * sample_rate) ;

%% プロトコール
% パラメータ：　試行ごとに異なる
[filename, filepath] = uigetfile('*.csv', 'プロトコールファイルを選択してください');
if isequal(filename, 0)
    disp('ファイルが選択されませんでした。処理を中止します。');
    return;
end
protocol_file = fullfile(filepath, filename);
Protocol = readtable(protocol_file);

% Protocol = readtable('demo_protocol.csv');

nTrial = height(Protocol);



%% DAQの初期化と設定
disp('DAQの初期化を行っています...');
dq = daq("ni");
dq.Rate = sample_rate;
addoutput(dq, "Dev1", {'ao0', 'ao1'}, "Voltage") ;


try
for iTrial = 1:nTrial

    % 何かのキーを押すまで待機
    msg = sprintf('%d試行目: %s  Foreperiod=%.1fs', ...
        iTrial, Protocol.CueText{iTrial}, Protocol.Foreperiod(iTrial)) ;
    disp(msg)


    if Protocol.Foreperiod(iTrial) <= ready_signal_duration
        error('試行%d: Foreperiod（%.1fs）はready_signal_duration（%.1fs）より大きくする必要があります。', ...
            iTrial, Protocol.Foreperiod(iTrial), ready_signal_duration) ;
    end


    switch Protocol.CueText{iTrial}
        case 'go'
            voltage_ao1 = voltage_go ;
        case 'nogo'
            voltage_ao1 = voltage_nogo ;
    end


    % 波形ベクトルの生成
    fp_s = round(Protocol.Foreperiod(iTrial) * sample_rate) ;

    waveform0 = [voltage_off    * ones(ini_s, 1); ...
                 voltage_trigOn * ones(trig_s, 1); ...
                 voltage_off    * ones(trig_to_ready_s, 1); ...
                 voltage_ready  * ones(ready_s, 1); ...
                 voltage_off    * ones(fp_s - ready_s + gonogo_s + off_s, 1)] ;

    waveform1 = [voltage_off * ones(ini_s + trig_s + trig_to_ready_s + fp_s, 1); ...
                 voltage_ao1 * ones(gonogo_s, 1); ...
                 voltage_off * ones(off_s, 1)] ;


    waveform = [waveform0, waveform1] ;

    % グラフ描画
    % tInd = (1:length(waveform)) / sample_rate;
    % plot(tInd, waveform);
    % xlabel('Time (s)');
    % ylabel('Voltage (V)');
    % title('LED出力波形の確認');
    % ylim([-6, 6]);


    % バッファへの書き込みと出力の実行 ===
    % Qualisys capture準備 + 待機姿勢への移行
    input(sprintf('[試行 %d/%d] Qualisysをcapture待機状態にし、準備ができたらEnterを押してください...', iTrial, nTrial));
    for iCount = 4:-1:1
        fprintf('  %d 秒後に開始...\n', iCount);
        pause(1);
    end
    fprintf('  → 試行開始\n');

    preload(dq, waveform);
    start(dq, 'Finite');
    waveform_duration = ini_duration + trig_signal_duration + trig_to_ready_interval + ...
                        Protocol.Foreperiod(iTrial) + gonogo_signal_duration + off_duration;
    pause(waveform_duration);   % 波形出力完了まで待機
    stop(dq);                   % DAQ状態をリセット

    % スイング完了前に次のEnterが押されるのを防ぐ
    fprintf('  スイング完了待機中 (%.0f秒)...\n', swing_max_duration);
    pause(swing_max_duration);
    fprintf('  → 次の試行に進んでください\n');

end




catch ME
write(dq,[0,0]);
rethrow(ME);
end
