% 2026-0420_02_practice_Qualysis_synchronization.m
% QTM外部トリガ送信の練習スクリプト（関数分離・複数回テスト版）
% sendQTMTrigger.m と同じフォルダに置いて使用すること

%% 1. パラメータ設定
nTrials = 3;          % テストするトライアル数
trialInterval = 5;    % トライアル間の待機時間（秒）

%% 2. DAQデバイスのセットアップ
disp('DAQデバイスのセットアップを開始します...');
dq = daq("ni");
addoutput(dq, "Dev1", "ao0", "Voltage"); % Qualisys Sync Trigger チャンネル
write(dq, 0); % 初期化（0V）
disp('セットアップ完了。');

%% 3. QTM側の準備確認
disp('');
disp('==============================================');
disp('【重要】QTM の操作を行ってください:');
disp('  1. Capture メニュー → Capture を選択');
disp('  2. Start Capture ダイアログ → Start ボタンを押す');
disp('  3. ステータスバーに "Waiting for trigger" と表示されたら準備完了');
disp('==============================================');
disp('');
input('準備ができたら Enter キーを押してください...', 's');

%% 4. 複数回トリガ送信テスト
for trial = 1:nTrials

    fprintf('\n--- トライアル %d / %d ---\n', trial, nTrials);

    % QTMが「Waiting for trigger」状態になるまで待つ
    % （2回目以降は、QTM側で次の計測のStartを押してもらう必要がある）
    if trial > 1
        disp('次のトライアルの準備：QTMで再度 Capture → Start を操作してください。');
        input('準備できたら Enter キーを押してください...', 's');
    end

    % トリガ送信（関数呼び出し）
    sendQTMTrigger(dq);

    % 計測中の待機
    fprintf('計測中... %d秒待機します。\n', trialInterval);
    pause(trialInterval);

    disp('このトライアルの計測時間が終了しました。');
    disp('QTMの画面で計測が行われていたか確認してください。');
end

%% 5. 終了処理
write(dq, 0);
disp('');
fprintf('全 %d トライアルのテストが完了しました。\n', nTrials);
disp('各トライアルでQTMの計測が正常に行われていたか確認してください。');
