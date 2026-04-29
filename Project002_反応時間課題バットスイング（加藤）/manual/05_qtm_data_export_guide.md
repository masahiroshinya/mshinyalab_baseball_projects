# QTM データ保存・エクスポートガイド

**作成日**: 2026-04-29  
**作成者**: mshinyalab (AI支援)

---

## 1. QTMのデータ保存の仕組み

QTMでキャプチャしたデータは、**現在開いているプロジェクトのフォルダ**に自動保存される（Auto backupが有効の場合）。

```
D:\MShinyaLab\Documents\QuslisysProjects\
└── 2026-0413 Kato test\       ← プロジェクトフォルダ
        ├── 2026-0429_simple_reaction_test.qtm
        ├── 2026-0429_go_nogo_test.qtm
        └── Calibrations\
```

### 保存先の確認方法
- **File → Open Project Folder** を選択するとWindowsエクスプローラーでプロジェクトフォルダが開く

---

## 2. 日付ごとにフォルダを分けて管理する方法

QTMにはキャプチャフォルダを個別指定する設定がない。日付ごとにデータを分けるには、**セッションごとに新しいプロジェクトを作成する**のが正しい運用方法。

### 新しいプロジェクトの作成手順（セッション開始時）

1. メニュー → **File → New Project** を選択する
2. プロジェクト名を日付入りで入力する
   - 例：`2026-0429 Kato test`
3. 保存先フォルダはデフォルト（`D:\MShinyaLab\Documents`）のままでOK
4. **OK** を押すと新しいプロジェクトフォルダが自動作成される

これ以降キャプチャしたデータは `2026-0429 Kato test\` フォルダに保存される。

### 新しいプロジェクト作成後に必要な追加作業

新しいプロジェクトには前回の設定が引き継がれないため、以下を再設定する。

| 設定項目 | 手順 |
|---|---|
| 剛体定義の読み込み | Project Options → 6DOF Tracking → **Load Bodies** → 前回保存したXMLファイルを選択 |
| Calculate 6DOF の有効化 | Project Options → Processing → Real time / Capture actions の `Calculate 6DOF` を両方ON |
| Capture time の設定 | Project Options → Processing → Capture time を90秒以上に設定 |
| Export to MATLAB file | Project Options → Processing → Capture actions の `Export to MATLAB file` をON |

設定後 **Apply → OK → File → Save Project** で保存する。

---

## 3. 1ファイルをMATLABファイル（.mat）としてエクスポートする

### 手順

1. エクスポートしたいキャプチャファイル（`.qtm`）をQTMで開く
2. 処理が済んでいない場合は **Processing → Process Current Measurement**（F7）を実行する
3. メニュー → **File → Export → MATLAB file** を選択する
4. 保存先フォルダとファイル名を指定して **保存** を押す

---

## 4. 複数ファイルをまとめてMATLABエクスポートする（Batch Process）

### 事前設定（初回のみ）

Project Optionsでエクスポートを自動化しておく。

1. **Project → Project Options → Processing** を開く
2. **Capture actions** の `Export to MATLAB file` にチェックを入れる
3. **Apply → OK → File → Save Project**

### Batch Processの実行手順

1. メニュー → **File → Batch Process...** を選択する
2. ファイル選択ダイアログが開く
3. プロジェクトフォルダ（例：`2026-0429 Kato test\`）に移動する
4. エクスポートしたい `.qtm` ファイルを **Ctrlキーを押しながら複数選択** する
5. **開く(O)** を押す
6. バッチ処理が実行され、各 `.qtm` ファイルと同じフォルダに `.mat` ファイルが生成される

> **注意**: Batch Processのファイル選択時、現在開いているプロジェクトフォルダとは別のフォルダにファイルがある場合、手動でナビゲートして目的のフォルダを開く必要がある。

### トラブルシューティング

| 症状 | 対処法 |
|---|---|
| ファイル選択ダイアログで目的のフォルダが空に見える | 別のフォルダにファイルが保存されている可能性がある。**File → Open Project Folder** でプロジェクトフォルダを確認してから改めてナビゲートする |
| Batch Processでファイルが開けない | 対象ファイルが別のプロジェクトに属している場合に発生することがある。対象プロジェクトを先に開いてから実行する（未解決・調査中）|

---

## 5. エクスポートされたMATLABファイルの内容

`.mat` ファイルをMATLABで読み込むと、以下のような変数が含まれる。

```matlab
load('2026-0429_simple_reaction_test.mat');
```

| 変数名 | 内容 |
|---|---|
| `Trajectories` | マーカーの3D座標データ（ラベル付き） |
| `RigidBodies` | 剛体の6DOFデータ（位置・姿勢） |
| `FrameRate` | キャプチャのフレームレート（Hz） |
| `Analog` | アナログ入力データ（DAQからの電圧信号など） |

> `Analog` チャンネルにはao0からのLED信号（イベントマーカー）が含まれるため、刺激タイミングと動作データの対応付けが可能。
