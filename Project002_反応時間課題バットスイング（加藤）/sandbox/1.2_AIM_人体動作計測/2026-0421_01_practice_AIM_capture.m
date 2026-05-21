% 2026-0421_01_practice_AIM_capture.m
% AIM人体動作計測の練習スクリプト（カウントダウン付きトリガ送信版）
% sendQTMTrigger.m と同じフォルダに置いて使用すること

%% 1. パラメータ設定
nTrials = 3;          % テストするトライアル数
trialInterval = 5;    % トライアル間の待機時間（秒）
countdownSec = 5;     % トリガ送信前のカウントダウン秒数（移動時間）

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

    % カウントダウン（Enter後に計測ポジションへ移動する時間を確保）
    fprintf('%d秒後にトリガを送信します。計測ポジションに移動してください。\n', countdownSec);
    for t = countdownSec:-1:1
        fprintf('  %d...\n', t);
        pause(1);
    end
    disp('トリガ送信！');

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
