% test_qualisys_sync.m
% Qualisys向けのSync信号(パルス)を出力するテスト
% チャンネル：ao0 のみ使用（Qualisys Sync Trigger）
% マニュアル準拠版：QTMの「Waiting for trigger」確認後に送信

%% 1. 初期設定
disp('DAQデバイスのセットアップを開始します...');

dq = daq("ni");

% チャンネルの追加（ao0 のみ：Qualisys Sync Trigger）
addoutput(dq, "Dev1", "ao0", "Voltage"); % Qualisys Sync Trigger

% 初期化（0Vにしておく）
write(dq, 0);
disp('セットアップ完了。');
disp('');
disp('==============================================');
disp('【重要】QTM の操作を行ってください:');
disp('  1. Capture メニュー → Capture を選択');
disp('  2. Start Capture ダイアログが開く');
disp('  3. Start ボタンを押す');
disp('  4. QTMのステータスバーに "Waiting for trigger" と');
disp('     表示されたことを確認する');
disp('==============================================');
disp('');
input('準備ができたら Enter キーを押してください...', 's');

%% 2. 同期テストの実行
disp('【トリガ送信】Qualisys(ao0)へトリガを送信します。');

% 1. ao0 を 5V に → 0V→5V の立ち上がりエッジでQTMがトリガを認識
write(dq, 5);

% 2. パルス幅を確保（50ms）
%    ※ QTMの最小遅延は20msのため、余裕を持って50msとする
pause(0.05);

% 3. ao0 を 0V に戻す（パルス終了）
write(dq, 0);

disp('  -> トリガ送信完了。');
disp('     QTMが自動的に計測を開始するはずです（20ms遅延後）。');

% 3秒待機（QTMの計測が行われる）
pause(3);

%% 3. リセット処理
disp('リセットして終了します。');
write(dq, 0);
disp('テスト完了です。QTMの画面で計測が開始されていたか確認してください。');
