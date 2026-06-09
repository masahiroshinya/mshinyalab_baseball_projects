
## x5_SingleTrialAnalysisResultsChecked — 1試行内分析の目視確認済み結果

ワークフロー ステップ5に対応。

`x4_SingleTrialAnalysisResults` の分析結果を目視確認し、問題なしと判断したデータを保存するフォルダ。

### 格納するもの
- 目視確認済みの分析結果（`.mat` ファイル）

### 確認のポイント
- 算出された変数が物理的に妥当な範囲にあるか
- 典型的な試行と異常な試行を視覚的に識別できるか

### 次のステップ
問題なければ `x6_MultiTrialAnalysisResults` へ進む。問題があれば `x4_SingleTrialAnalysisResults` の分析処理に戻る。
