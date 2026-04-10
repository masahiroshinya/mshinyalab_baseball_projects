

% DAQセッション（またはDataAcquisitionオブジェクト）の作成
dq = daq("ni");

% アナログ出力チャンネルの追加（Dev1の ao0）
addoutput(dq, "Dev1", "ao0", "Voltage");

% LEDを点灯させる (5Vを出力)
disp('LEDを点灯します');
write(dq, 5); % 5Vを出力
pause(2); % 2秒待機

% LEDを消灯させる (0Vを出力)
disp('LEDを消灯します');
write(dq, 0); % 0Vを出力

disp('テスト完了');



