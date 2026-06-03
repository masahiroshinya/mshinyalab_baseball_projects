# P学習ワークフロー：Go-Stop課題スクリプトを自分で書こう

## このフォルダの目的

このフォルダでは、Go-NoGo課題スクリプト
`../4.1_予備実験用スクリプト/demo3_4_2_gonogo_pre_regenerate.m`
を参考にしながら、Go-Stop課題用スクリプト
`demo3_4_3_gostop_pre.m`
を学習しながら作成する。

Go-Stop課題では、Go-NoGo課題とは異なり、全試行でまず1回目のGo cueを提示する。その後、わずかな消灯時間を挟み、2回目のCueとしてGoまたはStopを提示する。

```text
Ready cue
  ↓
Foreperiod
  ↓
1回目 Go cue
  ↓
短い消灯
  ↓
2回目 Cue（Go または Stop）
```

本ワークフローでは、1回目Go cueの提示時間と、その後の短い消灯時間を固定値として実装する。

---

## 全体の処理の流れ

`demo3_4_3_gostop_pre.m` が行う処理は以下の通り。

```text
[1] 初期化とパラメータ設定
[2] プロトコールCSVの読み込み
[3] DAQの初期化
[4] 試行ループの作成
[5] Go試行の波形作成
[6] Stop試行の波形作成
[7] DAQ出力
[8] エラー時の安全停止
```

---

## STEP 1：初期化と基本パラメータを書く

### 書くコード

`demo3_4_3_gostop_pre.m` の先頭に以下を書く。

```matlab
clear;
clc;
close all;

% AO0 ch を、Qualisys のトリガーボックス（NC0）に接続
% AO0 ch に白色LEDを正負反転で接続し、-5V出力時にready cueを点灯
% AO1 ch に緑/赤LEDを正負反転で接続し、+5VでGo、-5VでStopを点灯

sample_rate = 1000;

voltage_off     = 0;
voltage_trigOn  = 5.0;
voltage_ready   = -5.0;
voltage_go      = 5.0;
voltage_stop    = -5.0;

ini_duration            = 0.1;
trig_signal_duration    = 0.1;
trig_to_ready_interval  = 1.0;
ready_signal_duration        = 0.5;
first_go_signal_duration     = 0.1;
go_to_branch_off_duration    = 0.1;
second_go_signal_duration    = 0.5;
stop_signal_duration         = 0.5;
off_duration            = 0.1;
swing_max_duration      = 5.0;
```

### 解説

| コード                              | 意味                                            |
| ----------------------------------- | ----------------------------------------------- |
| `clear`                           | ワークスペースの変数を消去する                  |
| `clc`                             | コマンドウィンドウを消去する                    |
| `close all`                       | 開いているグラフをすべて閉じる                  |
| `sample_rate = 1000`              | DAQから1秒間に1000点の電圧を出力する            |
| `voltage_go = 5.0`                | 緑LED、つまりGo cueを点灯する電圧               |
| `voltage_stop = -5.0`             | 赤LED、つまりStop cueを点灯する電圧             |
| `first_go_signal_duration = 0.1`  | 1回目Go cueの提示時間。暫定値                   |
| `go_to_branch_off_duration = 0.1` | 1回目Go cue後、2回目Cue前の短い消灯時間。暫定値 |
| `second_go_signal_duration = 0.5` | Go試行で提示する2回目Go cueの時間               |
| `stop_signal_duration = 0.5`      | Stop試行で提示するStop cueの時間                |

- [X] STEP 1 のコードを追記し、実行してエラーが出ないことを確認する。

---

## STEP 2：プロトコールCSVを読み込む

### 書くコード

STEP 1 に続けて以下を書く。

```matlab
% プロトコールCSVの読み込み
[filename, filepath] = uigetfile('*.csv', 'プロトコールファイルを選択してください');

if isequal(filename, 0)
    disp('ファイルが選択されませんでした。処理を中止します。');
    return;
end

protocol_file = fullfile(filepath, filename);
Protocol = readtable(protocol_file);

nTrial = height(Protocol);
```

### 解説

| コード                           | 意味                                             |
| -------------------------------- | ------------------------------------------------ |
| `uigetfile('*.csv', ...)`      | CSVファイルを手動で選択するダイアログを開く      |
| `isequal(filename, 0)`         | ファイル選択がキャンセルされたかどうかを確認する |
| `fullfile(filepath, filename)` | フォルダ名とファイル名を結合して完全なパスを作る |
| `readtable(protocol_file)`     | CSVをテーブル形式で読み込む                      |
| `height(Protocol)`             | CSVの行数、つまり試行数を取得する                |

CSVは以下の形式にする。

```text
TrialNum,Foreperiod,CueText
1,1.4,go
2,1.6,stop
3,1.2,go
4,1.8,stop
5,1.5,go
```

- [X] STEP 2 のコードを追記し、`Protocol` が読み込まれることを確認する。
- [X] コマンドウィンドウで `Protocol` と入力し、`Foreperiod` と `CueText` が表示されることを確認する。

---

## STEP 3：DAQを初期化する

### 書くコード

STEP 2 に続けて以下を書く。

```matlab
% DAQの初期化と設定
disp('DAQの初期化を行っています...');

dq = daq("ni");
dq.Rate = sample_rate;

addoutput(dq, "Dev1", {'ao0', 'ao1'}, "Voltage");
```

### 解説

| コード                    | 意味                                         |
| ------------------------- | -------------------------------------------- |
| `daq("ni")`             | National Instruments のDAQデバイスを使用する |
| `dq.Rate = sample_rate` | 出力サンプリング周波数を設定する             |
| `addoutput(...)`        | AO0とAO1を電圧出力チャンネルとして追加する   |

AO0とAO1の役割は以下の通り。

| チャンネル | 役割                            |
| ---------- | ------------------------------- |
| AO0        | Qualisysトリガーと白色Ready LED |
| AO1        | 緑Go LEDと赤Stop LED            |

- [X] STEP 3 のコードを追記し、DAQ初期化でエラーが出ないことを確認する。

---

## STEP 4：試行ループを作る

### 書くコード

STEP 3 に続けて以下を書く。

```matlab
try

for iTrial = 1:nTrial

    msg = sprintf('%d試行目: %s  Foreperiod=%.1fs', ...
        iTrial, Protocol.CueText{iTrial}, Protocol.Foreperiod(iTrial));
    disp(msg);

    if Protocol.Foreperiod(iTrial) <= ready_signal_duration
        error('試行%d: Foreperiod（%.1fs）はready_signal_duration（%.1fs）より大きくする必要があります。', ...
            iTrial, Protocol.Foreperiod(iTrial), ready_signal_duration);
    end

end

catch ME
    write(dq, [0, 0]);
    rethrow(ME);
end
```

### 解説

| コード                          | 意味                                              |
| ------------------------------- | ------------------------------------------------- |
| `for iTrial = 1:nTrial`       | 1試行目から最終試行まで順番に処理する             |
| `Protocol.CueText{iTrial}`    | 現在の試行が `go` か `stop` かを取り出す      |
| `Protocol.Foreperiod(iTrial)` | 現在の試行のForeperiodを取り出す                  |
| `try-catch`                   | エラーが出た場合でもDAQ出力を0Vに戻すための安全策 |

Foreperiodは、ready cueが終わった後にGo cueを出すため、`ready_signal_duration` より長い必要がある。

- [X] STEP 4 のコードを追記し、各試行の情報が表示されることを確認する。

---

## STEP 5：Go試行の波形を作る

### 考え方

Go試行では、AO1に1回目Go cueを出し、短い消灯を挟んだ後、2回目Go cueを出す。

```text
AO1: 0V → +5V Go1 → 0V → +5V Go2 → 0V
```

AO0はQualisysトリガーとReady cueを担当する。

```text
AO0: 0V → +5V Trigger → 0V → -5V Ready → 0V
```

### 書くコード

次のSTEPで作る `switch` 文の `case 'go'` の中に書く。

```matlab
case 'go'

    waveform_duration = ini_duration + trig_signal_duration + trig_to_ready_interval + ...
        Protocol.Foreperiod(iTrial) + first_go_signal_duration + ...
        go_to_branch_off_duration + second_go_signal_duration + off_duration;

    waveform0 = [
        voltage_off    * ones(ini_duration * sample_rate, 1);
        voltage_trigOn * ones(trig_signal_duration * sample_rate, 1);
        voltage_off    * ones(trig_to_ready_interval * sample_rate, 1);
        voltage_ready  * ones(ready_signal_duration * sample_rate, 1);
        voltage_off    * ones((Protocol.Foreperiod(iTrial) - ready_signal_duration + first_go_signal_duration + go_to_branch_off_duration + second_go_signal_duration + off_duration) * sample_rate, 1)
    ];

    waveform1 = [
        voltage_off * ones((ini_duration + trig_signal_duration + trig_to_ready_interval + Protocol.Foreperiod(iTrial)) * sample_rate, 1);
        voltage_go  * ones(first_go_signal_duration * sample_rate, 1);
        voltage_off * ones(go_to_branch_off_duration * sample_rate, 1);
        voltage_go  * ones(second_go_signal_duration * sample_rate, 1);
        voltage_off * ones(off_duration * sample_rate, 1)
    ];
```

### 解説

| コード                              | 意味                               |
| ----------------------------------- | ---------------------------------- |
| `waveform0`                       | AO0に出力する電圧波形              |
| `waveform1`                       | AO1に出力する電圧波形              |
| `ones(duration * sample_rate, 1)` | 指定した秒数ぶんの縦ベクトルを作る |
| `voltage_go * ones(...)`          | その区間をすべて+5Vにする          |

Go試行の `waveform1` は、1回目Go cueの前までは0V、1回目Go cue中は+5V、短い消灯中は0V、2回目Go cue中は+5V、最後は0Vになる。

- [ ] Go試行の `waveform0` と `waveform1` の長さが一致することを確認する。

---

## STEP 6：Stop試行の波形を作る

### 考え方

Stop試行では、1回目Go cueを出し、短い消灯を挟んだ後、Stop cueを出す。

```text
AO1: 0V → +5V Go1 → 0V → -5V Stop → 0V
```

ここがGo-NoGo課題との最大の違いである。

### 書くコード

`switch` 文の `case 'stop'` の中に書く。

```matlab
case 'stop'

    waveform_duration = ini_duration + trig_signal_duration + trig_to_ready_interval + ...
        Protocol.Foreperiod(iTrial) + first_go_signal_duration + ...
        go_to_branch_off_duration + stop_signal_duration + off_duration;

    waveform0 = [
        voltage_off    * ones(ini_duration * sample_rate, 1);
        voltage_trigOn * ones(trig_signal_duration * sample_rate, 1);
        voltage_off    * ones(trig_to_ready_interval * sample_rate, 1);
        voltage_ready  * ones(ready_signal_duration * sample_rate, 1);
        voltage_off    * ones((Protocol.Foreperiod(iTrial) - ready_signal_duration + first_go_signal_duration + go_to_branch_off_duration + stop_signal_duration + off_duration) * sample_rate, 1)
    ];

    waveform1 = [
        voltage_off  * ones((ini_duration + trig_signal_duration + trig_to_ready_interval + Protocol.Foreperiod(iTrial)) * sample_rate, 1);
        voltage_go   * ones(first_go_signal_duration * sample_rate, 1);
        voltage_off  * ones(go_to_branch_off_duration * sample_rate, 1);
        voltage_stop * ones(stop_signal_duration * sample_rate, 1);
        voltage_off  * ones(off_duration * sample_rate, 1)
    ];
```

### 解説

Stop試行でも最初は必ず1回目Go cueを出す。

| 区間            | AO1の電圧 | 意味                     |
| --------------- | --------- | ------------------------ |
| 1回目Go cue前   | 0V        | 消灯                     |
| 1回目Go cue区間 | +5V       | Go cue点灯               |
| 短い消灯区間    | 0V        | Go cueと2回目Cueを分ける |
| Stop cue区間    | -5V       | Stop cue点灯             |
| 最後            | 0V        | 消灯                     |

今回の実装では、`first_go_signal_duration` の間だけ1回目Go cueを点灯し、`go_to_branch_off_duration` の短い消灯を挟んでからStop cueへ切り替える。

- [ ] Stop試行で `+5V → 0V → -5V` が出る構造になっていることを確認する。

---

## STEP 7：switch文でGo試行とStop試行を分ける

### 書くコード

STEP 4 の `for` ループ内、Foreperiodチェックの後に以下を書く。

```matlab
    switch Protocol.CueText{iTrial}

        case 'go'
            % STEP 5 のGo試行コードを書く

        case 'stop'
            % STEP 6 のStop試行コードを書く

        otherwise
            error('試行%d: CueText は go または stop にしてください。現在の値: %s', ...
                iTrial, Protocol.CueText{iTrial});
    end

    waveform = [waveform0, waveform1];
```

### 解説

| コード                     | 意味                                                    |
| -------------------------- | ------------------------------------------------------- |
| `switch`                 | 条件に応じて処理を分ける                                |
| `case 'go'`              | Go試行の波形を作る                                      |
| `case 'stop'`            | Stop試行の波形を作る                                    |
| `otherwise`              | 想定外の文字が入っていた場合にエラーを出す              |
| `[waveform0, waveform1]` | AO0とAO1の波形を横に並べ、2チャンネル出力用の行列にする |

- [ ] `go` と `stop` の両方で `waveform` が作られることを確認する。

---

## STEP 8：DAQに波形を出力する

### 書くコード

`waveform = [waveform0, waveform1];` の後に以下を書く。

```matlab
    input(sprintf('[試行 %d/%d] Qualisysをcapture待機状態にし、準備ができたらEnterを押してください...', iTrial, nTrial));

    for iCount = 4:-1:1
        fprintf('  %d 秒後に開始...\n', iCount);
        pause(1);
    end

    fprintf('  → 試行開始\n');

    preload(dq, waveform);
    start(dq, 'Finite');

    pause(waveform_duration);
    stop(dq);

    fprintf('  スイング完了待機中 (%.0f秒)...\n', swing_max_duration);
    pause(swing_max_duration);

    fprintf('  → 次の試行に進んでください\n');
```

### 解説

| コード                       | 意味                               |
| ---------------------------- | ---------------------------------- |
| `input(...)`               | 実験者がEnterを押すまで待つ        |
| `preload(dq, waveform)`    | DAQに出力波形を事前に読み込ませる  |
| `start(dq, 'Finite')`      | 有限長の波形出力を開始する         |
| `pause(waveform_duration)` | 波形出力が終わるまでMATLAB側で待つ |
| `stop(dq)`                 | DAQの出力動作を停止する            |

- [ ] 1試行ごとにEnter待機、カウントダウン、出力、スイング待機が行われることを確認する。

---

## STEP 9：完成後の確認チェックリスト

- [ ] CSVの `CueText` が `go` と `stop` になっている。
- [ ] Go試行ではAO1に `+5V → 0V → +5V` が出る。
- [ ] Stop試行ではAO1に `+5V → 0V → -5V` が出る。
- [ ] 2回目Cueは、1回目Go cueと短い消灯の後に出る。
- [ ] エラー時にAO0/AO1が `[0, 0]` に戻る。
- [ ] Qualisysのcapture待機後に、手動Enterで各試行を開始できる。

---

## 学習上のポイント

このスクリプトで最も重要なのは、Go-NoGo課題との違いをコード上で理解することである。

Go-NoGo課題：

```text
Go試行   : +5V
NoGo試行 : -5V
```

Go-Stop課題：

```text
Go試行   : +5V → 0V → +5V
Stop試行 : +5V → 0V → -5V
```

つまり、Stop試行は「赤だけを出す試行」ではなく、
「1回目のGoを出し、短い消灯を挟んだ後にStopをかける試行」である。
