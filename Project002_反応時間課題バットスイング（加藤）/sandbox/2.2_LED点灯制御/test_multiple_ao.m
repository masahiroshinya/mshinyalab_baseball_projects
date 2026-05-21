% test_multiple_ao.m
% 複数のAOチャンネル（ao0, ao1）を同時に制御するテストスクリプト
%% 1. 初期設定
disp('DAQデバイスのセットアップを開始します...');
% DataAcquisition オブジェクトの作成
dq = daq("ni");
% 複数チャンネルの追加 (Dev1 の ao0 と ao1)
addoutput(dq, "Dev1", "ao0", "Voltage");
addoutput(dq, "Dev1", "ao1", "Voltage");
disp('セットアップ完了。');
%% 2. 複数LEDの点灯テスト
% パターン1: ao0のみON (5V), ao1はOFF (0V)
disp('パターン1: ao0 (ON), ao1 (OFF)');
write(dq, [5, 0]);
pause(2); % 2秒待機
% パターン2: ao0はOFF (0V), ao1のみON (5V)
disp('パターン2: ao0 (OFF), ao1 (ON)');
write(dq, [0, 5]);
pause(2);
% パターン3: 両方ON (5V)
disp('パターン3: ao0 (ON), ao1 (ON)');
write(dq, [5, 5]);
pause(2);
% パターン4: 両方OFF (0V)
disp('パターン4: ao0 (OFF), ao1 (OFF) => 終了');
write(dq, [0, 0]);
disp('テスト完了です。');