# MATLABでデータ分析を行なうフォルダ



## 分析ワークフロー


１．Qualisys で計測した .mat ファイルを保存する

本実験では、生データは `../04_Data/<計測日>_S<被験者ID>/` に置いたまま参照する（x1_RawData/ にはコピーしない）。参照先は `x2_import_data.m` の `RawDataRoot` / `SubjectFolderArray` で指定する。

２．RawData を、MATLABで分析しやすいようにクリーニングする

クリーニングされたデータは、x2_Data/ に保存する

３．目視により、データがクリーニングされたことを確認する

確認済みのデータは、x3_DataChecked/ に保存する

４．1試行内で完結する分析

分析結果は、x4_SingleTrialAnalysisResults/ に保存する

５．４で得られた分析結果が正しいことを、目視により確認する

確認済みの分析結果は、x5_SingleTrialAnalysisResultsChecked/ に保存する

６．複数試行にまたがる分析

分析結果は、x6_MultiTrialAnalysisResults/ に保存する

７．６で得られた分析結果が正しいことを、目視により確認する

確認済みの分析結果は、x7_MultiTrialAnalysisResultsChecked/ に保存する

８．統計処理用のデータテーブルを作成する

データテーブルは、x8_StatTable/ に保存する

９．統計分析

分析結果は、x9_Statistics/ に保存する
