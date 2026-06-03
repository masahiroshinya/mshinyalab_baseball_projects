clear ;
clc ;
close all ;

% AO0 ch を、Qualisys のトリガーボックス（NC0）に接続
% AO0 ch に白色LEDを正負反転で接続し、-5V出力時にready cueを点灯
% AO1 ch に緑/赤LEDを接続（赤色LEDは正負反転）し、+5VでGo、-5VでStopを点灯

sample_rate = 1000 ;

voltage_off    = 0 ;
voltage_trigOn = 5.0 ;
voltage_ready  = -5.0 ;
voltage_go     = 5.0 ;
voltage_stop   = -5.0 ;

ini_duration              = 0.1 ;
trig_signal_duration      = 0.1 ;
trig_to_ready_interval    = 1.0 ;
ready_signal_duration     = 0.5 ;
first_go_signal_duration  = 0.1 ;
go_to_branch_off_duration = 0.1 ;
second_go_signal_duration = 0.5 ;
stop_signal_duration      = 0.5 ;
off_duration              = 0.1 ;
swing_max_duration        = 5.0 ;

% サンプル数を事前に整数として計算
ini_s              = round(ini_duration              * sample_rate) ;
trig_s             = round(trig_signal_duration      * sample_rate) ;
trig_to_ready_s    = round(trig_to_ready_interval    * sample_rate) ;
ready_s            = round(ready_signal_duration     * sample_rate) ;
first_go_s         = round(first_go_signal_duration  * sample_rate) ;
go_branch_off_s    = round(go_to_branch_off_duration * sample_rate) ;
second_go_s        = round(second_go_signal_duration * sample_rate) ;
stop_s             = round(stop_signal_duration      * sample_rate) ;
off_s              = round(off_duration              * sample_rate) ;

% プロトコールCSVの読み込み
[filename, filepath] = uigetfile('*.csv', 'プロトコールファイルを選択してください') ;

if isequal(filename, 0)
    disp('ファイルが選択されませんでした。処理を中止します。') ;
    return ;
end

protocol_file = fullfile(filepath, filename) ;
Protocol = readtable(protocol_file) ;

nTrial = height(Protocol) ;

% DAQの初期化と設定
disp('DAQの初期化を行っています...') ;

dq = daq("ni") ;
dq.Rate = sample_rate ;

addoutput(dq, "Dev1", {'ao0', 'ao1'}, "Voltage") ;

try

for iTrial = 1:nTrial

    msg = sprintf('%d試行目: %s Foreperiod=%.1fs', ...
        iTrial, Protocol.CueText{iTrial}, Protocol.Foreperiod(iTrial)) ;
    disp(msg) ;

    if Protocol.Foreperiod(iTrial) <= ready_signal_duration
        error('試行%d: Foreperiod（%.1fs）はready_signal_duration（%.1fs）より大きくする必要があります。', ...
            iTrial, Protocol.Foreperiod(iTrial), ready_signal_duration) ;
    end
    
    fp_s = round(Protocol.Foreperiod(iTrial) * sample_rate) ;

    switch Protocol.CueText{iTrial}

        case 'go'
            waveform_duration = ini_duration + trig_signal_duration + trig_to_ready_interval + ...
                Protocol.Foreperiod(iTrial) + first_go_signal_duration + ...
                go_to_branch_off_duration + second_go_signal_duration + off_duration;

            waveform0 = [
                voltage_off    * ones(ini_s, 1);
                voltage_trigOn * ones(trig_s, 1);
                voltage_off    * ones(trig_to_ready_s, 1);
                voltage_ready  * ones(ready_s, 1);
                voltage_off    * ones(fp_s - ready_s + first_go_s + go_branch_off_s + second_go_s + off_s, 1)
                ];

            waveform1 = [
                voltage_off * ones(ini_s + trig_s + trig_to_ready_s + fp_s, 1);
                voltage_go  * ones(first_go_s, 1);
                voltage_off * ones(go_branch_off_s, 1);
                voltage_go  * ones(second_go_s, 1);
                voltage_off * ones(off_s, 1)
                ];


        case 'stop'

            waveform_duration = ini_duration + trig_signal_duration + trig_to_ready_interval + ...
                Protocol.Foreperiod(iTrial) + first_go_signal_duration + ...
                go_to_branch_off_duration + stop_signal_duration + off_duration;

            waveform0 = [
                voltage_off    * ones(ini_s, 1);
                voltage_trigOn * ones(trig_s, 1);
                voltage_off    * ones(trig_to_ready_s, 1);
                voltage_ready  * ones(ready_s, 1);
                voltage_off    * ones(fp_s - ready_s + first_go_s + go_branch_off_s + stop_s + off_s, 1)
                ];

            waveform1 = [
                voltage_off  * ones(ini_s + trig_s + trig_to_ready_s + fp_s, 1);
                voltage_go   * ones(first_go_s, 1);
                voltage_off  * ones(go_branch_off_s, 1);
                voltage_stop * ones(stop_s, 1);
                voltage_off  * ones(off_s, 1)
                ];


        otherwise
            error('試行%d: CueTextは go または stop　にしてください。現在の値: %s', ...
                iTrial, Protocol.CueText{iTrial}) ;
    end

    waveform = [waveform0, waveform1] ;

    input(sprintf('[試行 %d/%d] Qualisysをcapture待機状態にし、準備ができたらEnterを押してください...', iTrial, nTrial)) ;

    for iCount = 4:-1:1
        fprintf(' %d 秒後に開始...\n', iCount) ;
        pause(1) ;
    end

    fprintf(' → 試行開始\n') ;

    preload(dq, waveform) ;
    start(dq, 'Finite') ;

    pause(waveform_duration) ;
    stop(dq) ;

    fprintf(' スイング完了待機中 (%.0f秒)...\n', swing_max_duration) ;
    pause(swing_max_duration) ;

    fprintf(' → 次の試行に進んでください\n') ;

end

catch ME
    write(dq, [0,0]) ;
    rethrow(ME) ;
end
