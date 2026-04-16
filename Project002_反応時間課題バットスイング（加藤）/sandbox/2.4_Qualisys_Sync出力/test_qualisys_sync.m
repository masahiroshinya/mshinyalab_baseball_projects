% test_qualisys_sync.m
% LEDの制御と同時にQualisys向けのSync信号(パルス)を出力するテスト

%% 1. 初期設定
disp('DAQデバイスのセットアップを開始します...');

dq = daq("ni");

% チャンネルの追加 (Dev1 の ao0, ao1 に加え、Sync用として ao2 を追加)
addoutput(dq, "Dev1", "ao0", "Voltage"); % LED 1
addoutput(dq, "Dev1", "ao1", "Voltage"); % LED 2
addoutput(dq, "Dev1", "ao2", "Voltage"); % Qualisys Sync Trigger

% 全チャンネルの初期化（0Vにしておく）
write(dq, [0, 0, 0]);

disp('セットアップ完了。テストまで2秒待機します...');
pause(2);

%% 2. 同期テストの実行

disp('【課題スタート】LED 1(ao0)を点灯させ、同時にQualisys(ao2)へトリガを送信します。');

% 1. LED(ao0)をON(5V)、Sync(ao2)もON(5V)
write(dq, [5, 0, 5]); 

% 2. ほんの一瞬待つ (トリガパルスの幅を確保、ここでは10msとする)
pause(0.01); 

% 3. LED(ao0)は点灯させたまま、Sync(ao2)はOFF(0V)に戻す
write(dq, [5, 0, 0]);

disp('  -> トリガ送信完了 (LEDは点灯中)');

% そのまま2秒間LEDを見せる
pause(2);

%% 3. リセット処理
disp('全体をリセットして終了します。');
write(dq, [0, 0, 0]);
disp('テスト完了です。');
