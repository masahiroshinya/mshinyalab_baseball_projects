
## x7_MultiTrialAnalysisResultsChecked — 複数試行分析の目視確認済み結果

ワークフロー ステップ7に対応。

`x6_MultiTrialAnalysisResults` の分析結果を目視確認し、問題なしと判断したデータを保存するフォルダ。

### 格納するもの
- 目視確認済みの統合分析結果（`.mat` ファイル）

### 確認のポイント
- 試行間のトレンドや異常値が確認できるか
- 条件間の比較が適切に行われているか

### 次のステップ
問題なければ `x8_StatTable` へ進む。問題があれば `x6_MultiTrialAnalysisResults` の分析処理に戻る。
