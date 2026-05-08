


clear;
clc;
close all;


% AO0 ch を、Qualisys のトリガーボックス（NC0）に接続　+5Vを出力することで、Qualisys測定開始
% AO0 ch に、白のLEDを、正負を反転させて接続することで、-5V出力時は白が点灯する（ready cue)
% AO1 ch に、緑のLEDを接続　+5V出力時に緑が点灯する（go cue）



% === ステップ1: 波形ベクトルの作成と確認 ===
% パラメータ：　全試行共通
sample_rate  = 1000;    % サンプリングレート [Hz]
voltage_off = 0 ;
voltage_trigOn = 5.0 ;
voltage_ready = -5.0 ;
voltage_go = 5.0 ;

ini_duration = 0.1;     % 最初の消灯時間 [秒]
trig_signal_duration = 0.1 ;
trig_to_ready_interval = 1.0 ;
ready_signal_duration = 0.5 ;
gonogo_signal_duration = 0.5 ;
off_duration = 0.1 ;
swing_max_duration = 5.0 ;  % go cue反応後からスイング終了までの最大時間 [秒]

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



    voltage_ao1 = voltage_go ;   % 単純選択反応は常に緑LED



    % 波形ベクトルの生成 AO0
    waveform0 = [voltage_off * ones(ini_duration * sample_rate,  1);... % 最初のゼロ
        voltage_trigOn * ones(trig_signal_duration * sample_rate,  1);... % Qualisysへのトリガー
        voltage_off * ones(trig_to_ready_interval * sample_rate,  1);... % トリガーからreadyまで
        voltage_ready * ones(ready_signal_duration * sample_rate,  1);... % ready
        voltage_off * ones((Protocol.Foreperiod(iTrial) - ready_signal_duration + gonogo_signal_duration + off_duration) * sample_rate,  1)] ; % 残り

    waveform1 = [voltage_off * ones((ini_duration + trig_signal_duration + trig_to_ready_interval + Protocol.Foreperiod(iTrial)) * sample_rate,  1);... % 最初のゼロ
        voltage_ao1 * ones(gonogo_signal_duration * sample_rate,  1);... % Go cue
        voltage_off * ones(off_duration * sample_rate,  1)] ;   % 残り

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
