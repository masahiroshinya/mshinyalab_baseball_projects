# pre予備実験プロトコール

作成日：2026-05-04  
更新日：2026-05-11

---

## 実験環境準備

1. Qualisys カメラスイッチ ON
   - 各種ソフトウェア起動（Antigravity、MATLAB、Qualisys）
2. 本プロトコール確認
3. キャリブレーション
4. バット準備（マーカー貼付・剛体登録済み）
5. テストスイング（各条件を実施）

---

## 実験

### ① 自由スイング

> **1試行 = 1 capture**（計5 capture）  
> 全3条件と同一の環境（外部トリガー・初期位置計測期間あり）で実施する。

1. Qualisys のカメラスタートトリガを **外部トリガ** に設定
2. Capture delay：**なし**、Capture 時間：**8秒以上** に設定
3. MATLAB 上で `demo3_4_0_free_pre.m` を実行
4. **各試行の手順（5回繰り返し）：**
   1. MATLAB コンソールに「Qualisys を capture 待機状態にし、準備ができたら Enter を押してください」と表示される
   2. Qualisys を capture 待機状態にセット
   3. バットを構えた状態で Enter を押す
   4. コンソールに 4・3・2・1 秒のカウントダウンが表示される
   5. カウントダウン終了後、MATLABが自動でトリガーを送信し計測開始
   6. トリガー後1秒間 静止（初期位置計測）→ 白LED（ready cue）→ 緑LED（go cue）でスイング
   7. capture 終了後、Qualisys で capture を停止・保存
   8. 次の試行へ

---

### ② Simple Reaction Task

> **1試行 = 1 capture**（計5 capture）

1. Qualisys のカメラスタートトリガを **外部トリガ** に設定
2. Capture delay：**なし**、Capture 時間：**8秒以上** に設定
3. MATLAB 上で `demo3_4_1_simplereaction_pre_regenerate.m` を実行
   - CSV ファイル選択画面が表示されるので、`demo3_4_1_simplereaction_pre_protocol_pilot_5trials.csv` を選択
4. **各試行の手順（5回繰り返し）：**
   1. MATLAB コンソールに「Qualisys を capture 待機状態にし、準備ができたら Enter を押してください」と表示される
   2. Qualisys を capture 待機状態にセット
   3. バットを構えた状態で Enter を押す
   4. コンソールに 4・3・2・1 秒のカウントダウンが表示される
   5. カウントダウン終了後、MATLABが自動でトリガーを送信し計測開始
   6. capture 終了後、Qualisys で capture を停止・保存
   7. 次の試行へ

---

### ③ Go No-Go Task

> **1試行 = 1 capture**（計5 capture）

1. Qualisys のカメラスタートトリガを **外部トリガ** に設定
2. Capture delay：**なし**、Capture 時間：**8秒以上** に設定
3. MATLAB 上で `demo3_4_2_gonogo_pre_regenerate.m` を実行
   - CSV ファイル選択画面が表示されるので、`demo3_4_2_gonogo_pre_protocol_pilot_5trials.csv` を選択
4. **各試行の手順（5回繰り返し）：**
   1. MATLAB コンソールに「Qualisys を capture 待機状態にし、準備ができたら Enter を押してください」と表示される
   2. Qualisys を capture 待機状態にセット
   3. バットを構えた状態で Enter を押す
   4. コンソールに 4・3・2・1 秒のカウントダウンが表示される
   5. カウントダウン終了後、MATLABが自動でトリガーを送信し計測開始
   6. capture 終了後、Qualisys で capture を停止・保存
   7. 次の試行へ
