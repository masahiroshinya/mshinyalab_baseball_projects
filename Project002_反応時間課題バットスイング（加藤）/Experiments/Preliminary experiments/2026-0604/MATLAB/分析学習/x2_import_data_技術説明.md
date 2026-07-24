# x2_import_data.m 技術説明 / Technical Notes

**作成日**: 2026-07-15
**作成者**: 加藤 和太郎 (student) / AI (Claude)

このファイルは `x2_import_data.m` に関する技術メモです。
コードの内容についての質問と回答、および発生したトラブルの記録を蓄積します。

`x2_import_data.m` の役割：Qualisys で計測した生データ（`x1_RawData/`）を読み込み、
メタ情報の付与・NaN補間・LEDデータ抽出・不要フィールド削除を行い、
被験者ごとに `x2_Data/DataXX.mat` として保存する（分析ワークフローの手順2）。

---

## トラブルシューティング記録

---

### [2026-07-15] コメントの文字化け（複数エンコーディングの混在）

**発見者：** 加藤 和太郎 (student) / AI (Claude)

**症状：**
- ファイル内の日本語コメントが `設?��?` `繝輔ぃ繧､繝ｫ` のように文字化けしていた。
- どのエンコーディングで開いても、一部だけが必ず化ける状態だった。

**原因：**
1つの `.m` ファイル内に **3種類のバイト状態が混在**していた（「まだら」状態）。

| 種類 | 例 | 説明 |
|---|---|---|
| 正常な Shift-JIS | 15行目 `2026-0604_予備実験`、`Analog なし →` | Shift-JISで書かれ、UTF-8で開くと化ける |
| UTF-8を Shift-JIS として誤読 | `繝輔ぃ繧､繝ｫ`（＝「ファイル」） | UTF-8のバイトなのにShift-JISで解釈された |
| 壊れたUTF-8（バイト欠損） | `保存完�?`（`了`が欠損） | UTF-8だが一部バイトが `�`(U+FFFD) に化けた |

`file -I x2_import_data.m` が `charset=unknown-8bit`、`NEL line terminators`
（＝Shift-JISの2バイト目 0x85 等）を報告したのが混在の証拠。
MATLABエディタ（環境によりShift-JIS前提）とUTF-8で書き込むツールが交互に
このファイルを保存したことで、Shift-JISバイトとUTF-8バイトが混ざったと推定される。

**重要な切り分けポイント：**
コメント（`%`）自体は実行に影響しないが、**15行目はコード中の文字列リテラル**である。

```matlab
rawDataFolder = 'x1_RawData/2026-0604_予備実験' ;
```

ディスク上の実フォルダ名は UTF-8 の `2026-0604_予備実験`（`ls` で確認済み）。
この行のエンコーディングがずれると MATLAB がフォルダを見つけられず `load` が失敗する。
＝文字化けは「見た目だけ」の問題ではなく、機能に影響しうる。

**解決策：**
ファイル全体を **1つのエンコーディング（UTF-8）に統一**する。

- macOSの新しめのMATLAB（R2020a以降）は `.m` を UTF-8 で読み書きするため UTF-8 に統一する。
- 混在状態のまま「UTF-8で保存」すると、今度はShift-JIS部分（`予備実験`・`なし →`）が化けるので、
  残っている日本語は一度すべて打ち直してから保存する（コピペより直接入力が確実）。
- 現状で打ち直しが必要だった箇所：
  - 15行目 `'x1_RawData/2026-0604_予備実験'`
  - 66行目 `fprintf('Warning: Analog なし → %s\n', fileName) ;`
  - 90行目 `fprintf('保存完了 / Saved: %s.mat\n', dataFilePath) ;`（`完了` を打ち直す）
- 保存時：「名前を付けて保存 → エンコーディング UTF-8」で保存する。

---

## コードに関する質問と回答（Q&A）

---

### Q. `length` は何の長さを示していますか？（17行目）

```matlab
nCondition = length(ConditionNameArray) ;
```

**A.** ここでの `length` は **配列 `ConditionNameArray` の要素数（＝条件の数）** を返す。

`ConditionNameArray` は5行目で定義されたセル配列：

```matlab
ConditionNameArray = {'free', 'simple', 'gonogo'} ;   % 3要素
```

要素が3つ（free / simple / gonogo）なので `nCondition = 3` になる。

**なぜこう書くのか：**
すぐ下の条件ループで使う。条件数を直接 `3` と書かず `length(...)` で数えることで、
将来 `ConditionNameArray` に条件を増減させてもループ回数が自動で一致する。

```matlab
for iCondition = 1:nCondition            % 1:3 → 条件を1つずつ処理
    conditionName = ConditionNameArray{iCondition} ;
    ...
```

**補足（`length` の正確な意味と注意点）：**
`length(X)` は厳密には「Xの最も大きい次元のサイズ」を返す（`max(size(X))` と同じ）。
- 今回のような横一列の配列では「要素数」と一致するので直感どおり。
- ただし行列（例: 5×10）に使うと大きい方の `10` が返り、意図とズレることがある。
- 要素の総数がほしいときは `numel()`、特定次元のサイズは `size(X, 2)` と使い分けるのが安全。

---

### Q. `sprintf` と `fprintf` の違いは？（28・66・90行目）

**A.** 出力先が違う。書式指定（`%02d` などの使い方）は同じ。

| 関数 | 出力先 | 用途 | 覚え方 |
|---|---|---|---|
| `sprintf` | 文字列（変数）に格納 | 後で使う文字列を組み立てる | s = string |
| `fprintf` | 画面（コマンドウィンドウ）やファイルに出力 | 表示・書き出し | f = file |

**`sprintf`（文字列を作る）— 28行目：**

```matlab
fileName = [sprintf('S%02d_', iSubject), conditionName, sprintf('%04d', iTrial)] ;
```

`sprintf('S%02d_', 1)` は `'S01_'` という**文字列を返して** `fileName` に格納する。
画面には何も表示されない。この文字列を後で `load_qualisys_mat` に渡してファイルを読み込む。

**`fprintf`（画面に表示する）— 90行目：**

```matlab
fprintf('保存完了 / Saved: %s.mat\n', dataFilePath) ;
```

`dataFilePath` を埋め込んだ文章を**コマンドウィンドウに表示**する
（例: `保存完了 / Saved: x2_Data/Data01.mat`）。変数には格納されない。進捗表示が目的。

**関係：** `fprintf(str)` は「画面に出す」、`sprintf(str)` は「その文字列を返す」。
`fprintf('%s\n', sprintf('S%02d', 1))` のように組み合わせも可能。

**書式記号のおさらい（このコードで使用中）：**
- `%02d` … 整数を2桁でゼロ埋め（`1` → `01`）
- `%04d` … 整数を4桁でゼロ埋め（`1` → `0001`）
- `%s` … 文字列をそのまま埋め込む
- `\n` … 改行

---

### Q. `X = load_qualisys_mat(...)` の `X` は何のために置いているのか？（31行目〜）

```matlab
X = load_qualisys_mat(rawDataFolder, fileName) ;
X.SubjectID     = iSubject ;
X.ConditionCode = iCondition ;
X.ConditionName = conditionName ;
X.TrialNumber   = iTrial ;
X.ErrorCode     = 0 ;
X.ErrorText     = '' ;
```

**A.** `X` は「1試行分のデータをまとめて入れる箱（構造体 struct）」。

`load_qualisys_mat` は構造体を返す関数（`Data.Markers`, `Data.Force1` などを持つ）。
その返り値を `X` に受け取っているので、この時点で `X` には
マーカー軌跡・床反力などがすでに入っている。

`X.〇〇 = ...` は**新しい変数を作っているのではなく、既にある `X` にフィールドを追記**している。
- 例: `X.SubjectID = iSubject` は「箱Xに `SubjectID` という名札をつけて被験者番号を入れる」。

**なぜ `X` に置くのか（3つの理由）：**
1. **1試行のデータを1つにまとめて扱うため**：マーカー・床反力・被験者番号・条件・エラー情報を
   バラバラの変数にせず、1つの構造体で持ち運ぶ。
2. **識別情報を後付けするため**：計測データには「何番の被験者・どの条件・何試行目か」が入っていない。
   `X` に受けてから `X.SubjectID = ...` 等を追記し、データ単体で素性が分かるようにする（メタ情報の付与）。
3. **最後に配列へ格納するため**：後段で `DataArray(iTrial, iCondition) = XX` として大きな配列にまとめる。
   一時変数 `X` に入れることで「加工 → 格納」の流れを作れる。

**`X` という名前について：** 深い意味はなく作業用の一時変数名。`Data` でも `trial` でも動作は同じ。
ここでは「読み込んだ生データ（未加工）」を `X`、加工後を `XX` と置く命名になっている。

**関連メモ：** `load_qualisys_mat.m` 自体のコメント（5〜8行目・59行目）も同じ Shift-JIS 文字化けあり（未対応）。
