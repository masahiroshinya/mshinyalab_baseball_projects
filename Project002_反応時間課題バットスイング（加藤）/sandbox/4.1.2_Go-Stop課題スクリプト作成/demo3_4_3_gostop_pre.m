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

    if Protocol.Foreperiiod(iTrial) <= ready_signal_duration
        error('試行%d: Foreperiod（%.1fs）はready_signal_duration（%.1fs）より大きくする必要があります。', ...
            iTrial, Protocol.Foreperiod(iTrial), ready_signal_duration) ;
    end

end

catch ME
    write(dq, [0,0]) ;
    rethrow(ME) ;
end

       