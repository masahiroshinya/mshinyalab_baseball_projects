% test_protocol_presentation.m
% プロトコールCSVを読み込み、NI DAQ経由でLED制御を行うテストスクリプト

%% ===== 1. 設定セクション =====
disp('--- テストプログラム初期設定 ---');

% 読み込むプロトコールCSVファイルのパス
csv_file = '../3.1_プロトコールCSV設計/protocol_sample.csv';

% テスト実行する試行数（全部やると長いので絞る）
n_test_trials = 5;

% ハードウェア（チャンネル）と色の対応設定
% [ao0(R), ao1(G), ao2(B)] の電圧(V)配列を返す関数またはマップを後で定義する
device_id = "Dev1";
ch_r = "ao0";
ch_g = "ao1";
ch_b = "ao2";

%% ===== 2. CSV読み込み =====
if ~isfile(csv_file)
    error('CSVファイルが見つかりません: %s\nパスを確認してください。', csv_file);
end

% 文字列データをstring型として読み込む設定
opts = detectImportOptions(csv_file);
opts = setvartype(opts, {'condition', 'trial_type', 'stimulus_color', 'response_required', 'notes'}, 'string');
protocol_tbl = readtable(csv_file, opts);

% テスト実行用の試行数に絞る
total_trials = height(protocol_tbl);
run_trials = min(n_test_trials, total_trials);
test_tbl = protocol_tbl(1:run_trials, :);

fprintf('CSVを読み込みました。全 %d 試行のうち、最初の %d 試行を実行します。\n\n', total_trials, run_trials);

%% ===== 3. DAQセットアップ =====
disp('DAQのセットアップ中...');
try
    dq = daq("ni");
    addoutput(dq, device_id, ch_r, "Voltage"); % 赤
    addoutput(dq, device_id, ch_g, "Voltage"); % 緑
    addoutput(dq, device_id, ch_b, "Voltage"); % 青

    % 初期化（全消灯）
    write(dq, [0.0, 0.0, 0.0]);
    disp('DAQのセットアップ完了。');
catch ME
    warning('DAQの初期化に失敗しました。ハードウェアが接続されているか確認してください。');
    rethrow(ME);
end

fprintf('\n=== テスト開始（3秒後にスタートします） ===\n');
pause(3.0);

%% ===== 4. 試行ループ（刺激呈示） =====

try
    for i = 1:run_trials
        % --- 現在の試行データを取得 ---
        cond      = test_tbl.condition(i);
        color     = test_tbl.stimulus_color(i);
        isi_time  = test_tbl.isi_sec(i);
        led_dur   = test_tbl.led_duration_sec(i);
        v_on      = test_tbl.voltage_on(i);
        
        % 出力電圧配列 [R, G, B] を決定
        volt_out = [0.0, 0.0, 0.0];
        if v_on > 0
            if strcmp(color, "white")
                volt_out = [v_on, v_on, v_on];
            elseif strcmp(color, "red")
                volt_out = [v_on, 0.0, 0.0];
            elseif strcmp(color, "green")
                volt_out = [0.0, v_on, 0.0];
            elseif strcmp(color, "none")
                volt_out = [0.0, 0.0, 0.0];
            end
        end

        % 進捗表示
        fprintf('Trial %d/%d: condition=%s, color=%s, ISI=%.2fs, Dur=%.3fs\n', ...
                i, run_trials, cond, color, isi_time, led_dur);

        % --- ISI の待機 ---
        % tic / toc を用いた高精度なループ待機
        t_start_isi = tic;
        while toc(t_start_isi) < isi_time
            % 待機（空ループによるCPU占有を防ぐため微小なpauseを入れる）
            pause(0.001);
        end

        % --- LED点灯 ---
        write(dq, volt_out);

        % --- 点灯時間の待機 ---
        t_start_led = tic;
        while toc(t_start_led) < led_dur
            pause(0.001);
        end

        % --- LED消灯 ---
        write(dq, [0.0, 0.0, 0.0]);
    end

    disp('テストが正常に完了しました。全チャンネルを消灯しました。');

catch ME
    % エラー発生時でも必ずLEDを消灯させる安全処理
    disp('エラーまたは中断が発生しました。デバイスを安全な状態に戻します。');
    if exist('dq', 'var')
        write(dq, [0.0, 0.0, 0.0]);
    end
    rethrow(ME);
end

% 最後に念のため消灯
write(dq, [0.0, 0.0, 0.0]);
