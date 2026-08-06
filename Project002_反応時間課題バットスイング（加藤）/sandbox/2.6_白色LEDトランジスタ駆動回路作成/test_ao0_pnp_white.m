% test_ao0_pnp_white.m（案）
% AO0チャネルから -5V / 0V / +5V を順に出力し、PNP駆動の白色LEDの動作を確認する

dq = daq("ni");
addoutput(dq, "Dev1", "ao0", "Voltage");

% --- ① -5V：Ready cue → 点灯するはず ---
disp('AO0から -5V を出力します（5秒間）→ 白色LEDが【点灯】するはず');
write(dq, -5);
pause(5);

% --- ② 0V：待機 → 消灯するはず ---
disp('AO0を 0V に戻します（3秒間）→ 白色LEDが【消灯】するはず');
write(dq, 0);
pause(3);

% --- ③ +5V：Qualisysトリガー → 消灯のままのはず ---
disp('AO0から +5V を出力します（5秒間）→ 白色LEDは【消灯のまま】のはず');
write(dq, 5);
pause(5);

% --- 終了 ---
write(dq, 0);
disp('テスト完了');
