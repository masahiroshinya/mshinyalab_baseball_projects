# QTM (Qualisys Track Manager) 使用マニュアル サマリー

**参照元**: https://docs.qualisys.com/qtm/content/welcome_to_qtm.htm  
**対象バージョン**: QTM 2026.1  
**作成日**: 2026-04-20  
**作成者**: mshinyalab (AI支援)

---

## 目次

1. [QTMの同期機能の全体像](#1-qtmの同期機能の全体像)
2. [Sync Out（QTMから外部への信号出力）](#2-sync-outqtmから外部への信号出力)
3. [External Trigger（外部からQTMへのトリガ入力）](#3-external-trigger外部からqtmへのトリガ入力)
4. [Trigger Ports の設定](#4-trigger-ports-の設定)
5. [Synchronization Output の設定（Project Options）](#5-synchronization-output-の設定project-options)
6. [本プロジェクトへの適用方針](#6-本プロジェクトへの適用方針)

---

## 1. QTMの同期機能の全体像

QTMの同期機能は大きく **2つの方向** に分類される。

| 方向 | 名称 | 概要 |
|------|------|------|
| **QTM → 外部機器** | **Sync Out / Synchronization Output** | カメラ計測中にQTMがパルス信号を出力し、外部機器（アナログボード等）を同期させる |
| **外部機器 → QTM** | **External Trigger / Trigger Ports** | 外部機器からのTTL信号をQTMが受信し、計測の開始・終了をトリガする |

**本プロジェクト（タスク2.4、2.5）で使うのは「外部機器 → QTM 方向（External Trigger）」。**  
すなわち、NI DAQボードから電圧パルスを送り、QTMの計測をトリガする。

---

## 2. Sync Out（QTMから外部への信号出力）

> **参照**: `system_hardware/using_sync_out_for_synchronization.htm`

### 概要

- **Sync out** はカメラから出力される信号で、アナログボードとの同期に最推奨の方法。
- Sync outは **カメラが計測中にのみ active となるTTLパルス列** として出力される。
- プレビュー中はフレームごとにパルスが送られる。計測中も同様にフレームごとのパルスが出力される。

### Sync Outの信号タイムライン（計測の流れ）

| ステップ | 状態 | Sync Out 信号 |
|---------|------|--------------|
| 1. Preview 開始 | カメラがプレビュー中 | 各フレームごとにパルス送出 |
| 2. Capture メニュー → Capture 選択 | スタートトリガ待ちへ | パルス継続（プレビューが続いているため） |
| 3. Start Capture ダイアログが開く | プレビュー継続 | パルス継続 |
| 4. Start ボタンを押す | 計測待機（Waiting for measurement）| **パルス停止** |
| 5. Waiting for measurement | トリガ待ち状態 | **停止中**（external triggerなら押すまで継続） |
| 6. トリガ入力 or ボタン押下 | 計測開始 | **最初のカメラフレームの負エッジでスタート** |
| 7. 計測中 | 計測中 | 各フレームごとにパルス送出 |
| 8. 計測終了 | 計測停止 | パルスは高レベル（High）のまま、次のプレビューまで停止 |

> **NOTE (バッチキャプチャ)**: バッチキャプチャでは計測間のプレビューフレームがパルスとして出力されるため、外部機器はこれを考慮する必要がある。

### Sync Outの信号仕様
- 信号の種類: **TTLパルス列**（High/Low）
- Activeなのはカメラが計測中のみ
- **external triggerを使用する場合**：「Waiting for measurement」の期間が長くなるため、外部機器の初期化に時間を使えるというメリットがある

---

## 3. External Trigger（外部からQTMへのトリガ入力）

> **参照**: `system_hardware/how_to_use_external_trigger.htm`

### 概要

- 外部トリガ（External Trigger）を使うと、**外部機器からの信号でモーションキャプチャの開始をトリガ**できる。
- Oqusシステムの場合：スプリッタケーブルをいずれかのカメラのコントロールポートに接続してトリガ信号を入力する。
- Miqusシステムの場合：**Camera Sync Unit (CSU)** が必要。CSUのTrig NO または Trig NC 入力に接続する。

### 重要な仕様

| 項目 | 仕様 |
|------|------|
| **トリガ開始とキャプチャ開始の最小遅延** | **20 ms（20,000 μs）** |
| 停止トリガの遅延 | 設定した開始遅延の **2倍** |
| 接続先（Oqus） | カメラのコントロールポートへのスプリッタケーブル |
| 接続先（Miqus / CSU） | CSUの **Trig NO**（Normally Open）または **Trig NC**（Normally Closed）入力 |

> **⚠️ 重要**: トリガ信号を送るタイミングは、QTMのステータスバーに **「Waiting for trigger」** と表示されてからにすること。それより前に信号を送るとエラーになる場合がある。

### 外部トリガデバイスの例
- トリガボタン
- フォトセル
- その他の外部システム（**本プロジェクトではNI DAQボードが該当**）

### プレトリガとの組み合わせ
- 計測対象の動作が非常に短い場合、外部トリガと **プレトリガ（Pretrigger）** を組み合わせることで、トリガ前の動作も記録できる。

---

## 4. Trigger Ports の設定

> **参照**: `project_options/trigger_ports.htm`  
> QTMメニュー: **Project Options > Input Devices > Camera system > Synchronization > Trigger ports**

### 概要

**Trigger port(s)** 設定は、外部トリガデバイスを使ってQualisysシステムをトリガするすべての設定を管理する。

- **Oqusシステム**: スプリッタケーブルをカメラのコントロールポートに接続
- **Miqusシステム (CSU使用)**: CSUのTrig NO（Normally Open）とTrig NC（Normally Closed）の2入力を個別に設定可能

> CSU の Trig NO はQualisysトリガボタンと一緒に使用可能。  
> CSU の Trig NC は 「High レベル（5 Volt）」を出力できる外部デバイスが必要。  
> **→ 本プロジェクトのNI DAQボードはao2チャンネルで5V出力が可能なため、Trig NC に対応できる。**

### 設定項目

| 設定名 | 内容 |
|--------|------|
| **Function / Trig NO Function / Trig NC Function** | ドロップダウンから外部トリガの機能を選択 |
| → Start and stop capture disabled | 外部トリガはキャプチャ開始・終了に使わない（イベント作成のみ） |
| → **Start capture** | 外部トリガでキャプチャを **開始** する |
| → Stop capture | 外部トリガでキャプチャを **停止** する |
| → Start and stop capture | 外部トリガで開始・停止の両方を行う |
| **TTL signal edge** | トリガとして認識する信号の極性（Positive／Negative） |
| **Event color** | このトリガで作成されるイベントの色 |
| **Event text** | このトリガで作成されるイベントのラベル |
| **Generate events** | 外部トリガでイベントを生成するか（デフォルトON） |
| **Hold-off time** | 最後のイベントから新しいイベントが生成されるまでの待ち時間（デフォルト100ms、範囲5〜1000ms）。スイッチのチャタリング対策。 |
| **Delay from signal to start/stop [μs]** | トリガ信号からキャプチャ開始までの遅延（μs単位）。**最小20,000μs（20ms）**。停止遅延は開始遅延の2倍。 |
| **Minimum time between start and stop [s]** | 開始・停止信号の間の最小時間。範囲は1〜1000秒。外部トリガ入力すべてに適用（Wireless/software triggerは除く）。 |

> **NOTE**: QualisysトリガボタンをOqus Trig inコネクタまたはCSU Trig NO入力に接続した場合、ボタンを押すと**負エッジ**が、離すと**正エッジ**が生成される（デバウンスなし）。

---

## 5. Synchronization Output の設定（Project Options）

> **参照**: `project_options/synchronization_output.htm`  
> QTMメニュー: **Project Options > Input Devices > Camera system > Synchronization > Synchronization output**

### 概要

CSU（Camera Sync Unit）には3つの同期出力がある：

| 出力 | 説明 |
|------|------|
| **Out 1** | カスタマイズ可能な同期出力 |
| **Out 2** | カスタマイズ可能な同期出力 |
| **Measurement time** | キャプチャ中のみアクティブなパルス。プレビュー中は出力されない。 |

Oqusシステムの場合は、各カメラにスプリッタケーブルを接続することで同期出力にアクセスできる。

### 同期出力の種類

| モード | 説明 |
|--------|------|
| **Camera frequency – Shutter out** | カメラのフレームレートに同期したパルス |
| **Measurement time** | 計測中のみ信号出力（プレビュー・計測の両方ではなく計測のみ） |
| **100 Hz continuous** | 常に100Hzで出力（計測中・プレビュー中・待機中すべてで出力） |

> **NOTE**: CSUがシステムに含まれている場合、QTMはCSUのみの同期設定を表示し、OqusカメラのSynchronization settingsは表示されない。

---

## 6. 本プロジェクトへの適用方針

### タスク 2.4: QTMへのSync信号送信（現在のタスク）

```
NI DAQ (ao2) --[5V パルス]--> QTM の Trig in (Trigger Port)
```

**手順の流れ（MATLABとQTMの操作手順）**:

1. **QTM側の準備**：
   - Project Options > Input Devices > Camera system > Synchronization > Trigger ports を開く
   - `Function`（または `Trig NC: Function`）を **「Start capture」** に設定
   - `Delay from signal to start/stop` = **20000 μs（20ms）以上** を設定
   - `TTL signal edge` を **Positive**（0V→5Vの立ち上がりエッジ）に設定

2. **QTMの計測を「外部トリガ待ち」状態にする**:
   - Capture → Capture → Start ボタンを押してキャプチャモードに入る
   - ステータスバーに **「Waiting for trigger」** と表示されることを確認する

3. **MATLABから電圧パルスを送る**（`test_qualisys_sync.m` を実行）:
   ```matlab
   write(dq, [5, 0, 5]);   % LED ON + Sync トリガ送信（5V）
   pause(0.01);             % 10ms パルス幅
   write(dq, [5, 0, 0]);   % LED はONのまま、Sync は 0V に戻す
   ```
   - この「0V → 5V → 0V」の立ち上がりエッジをQTMがトリガとして認識する
   - パルス幅は10ms（最小遅延の20msよりは短いが、エッジの認識には十分）

4. **QTMが自動的に計測を開始する（20ms遅延後）**

### タスク 2.5: QTMの計測を同期待ちモードに設定する

上記手順のうち「QTM側の準備」「Waiting for trigger 状態への移行」を確実に実施できるよう、手順書化・検証を行う。

---

## 参考：QTMドキュメントの主要ページ一覧

| ページ名 | URL |
|----------|-----|
| Welcome to QTM | `welcome_to_qtm.htm` |
| How to use external trigger | `system_hardware/how_to_use_external_trigger.htm` |
| Using Sync out for synchronization | `system_hardware/using_sync_out_for_synchronization.htm` |
| Trigger ports (Project Options) | `project_options/trigger_ports.htm` |
| Synchronization output (Project Options) | `project_options/synchronization_output.htm` |
| External timebase | `project_options/external_timebase.htm` |
| Pretrigger | `project_options/pretrigger_options.htm` |
| Measurement with analog capture while using pretrigger | `system_hardware/measurement_with_analog_capture_while_using_pretrigger_and.htm` |

すべてのページは `https://docs.qualisys.com/qtm/content/` の配下。
