# 先行研究検索Agent

このファイルは、Project001「打者の動作撮影」における先行研究検索のための作業ルールである。目的は、検索漏れを減らし、論文の採否判断とメモ化を一定の品質で行うこと。

## 1. 基本方針

- 保存先は原則として `research_notes/未読/` とする。
- 1論文につき1つのMarkdownファイルを作成する。
- ファイル名は `YYYY_author_shorttitle.md` を基本とする。
- PDFを保存する場合は `research_notes/PDFs/` に置き、Markdownから相対リンクする。
- 読了・整理済みになったものは、ユーザー確認後に `research_notes/読了/` へ移す。
- 検索結果は、単に集めるのではなく「この研究に使えるか」を必ず評価する。

## 2. 先行研究検索で分解すべき要素

### A. 研究目的

- 何を明らかにしたいか
- どの動作・現象を対象にするか
- 精度検証なのか、動作特徴の抽出なのか、介入効果の評価なのか
- 実験室研究か、現場応用研究か
- 臨床・スポーツ・教育・コーチングのどれに近いか

例:

- 打者のスイング動作をスマートフォン動画で定量化できるか
- マーカーレスモーションキャプチャの関節角度推定精度はどの程度か
- 打撃パフォーマンスと体幹・下肢運動の関係は何か

### B. 対象者

- 競技レベル: プロ、大学生、高校生、ジュニア、初心者
- 性別、年齢、利き手・利き打ち
- 健常者か、障害・疼痛ありか
- サンプルサイズ
- 野球、ソフトボール、クリケット、ゴルフなど近接競技を含めるか

検索語候補:

- baseball hitter
- baseball batting
- softball batting
- cricket batting
- golf swing
- athlete
- youth athlete
- collegiate baseball

### C. 動作課題

- ティーバッティング
- トスバッティング
- 実投球への打撃
- 素振り
- 投球速度や球種の有無
- 試技数
- 成功試技・失敗試技の扱い
- スイング局面の定義

局面例:

- 構え
- ステップ開始
- 足接地
- バット加速
- インパクト
- フォロースルー

検索語候補:

- batting swing
- hitting mechanics
- swing phase
- stride foot contact
- bat-ball impact
- follow-through

### D. 計測方法

- 光学式3Dモーションキャプチャ
- IMU
- フォースプレート
- 高速度カメラ
- 通常動画
- スマートフォン動画
- マーカーレスモーションキャプチャ
- OpenPose、MediaPipe、DeepLabCut、Theia、SPLYZA Motion など

確認事項:

- カメラ台数
- 撮影方向
- フレームレート
- 解像度
- キャリブレーション方法
- マーカーあり・なし
- センサー装着位置
- 参照標準の有無

検索語候補:

- markerless motion capture
- pose estimation
- smartphone motion analysis
- video-based motion analysis
- inertial measurement unit
- optical motion capture
- biomechanics

### E. 分析対象の身体部位

- 頭部
- 体幹
- 骨盤
- 股関節
- 膝関節
- 足関節
- 肩関節
- 肘関節
- 手関節
- バット、グリップ、バレル
- 重心、COM

野球打撃で特に見る候補:

- 骨盤回旋
- 胸郭回旋
- 体幹分離
- 股関節回旋
- 前脚接地
- 後脚荷重
- 肩・肘の角度
- バット速度
- スイング軌道

### F. 指標

- 関節角度
- 関節角速度
- セグメント角度
- セグメント角速度
- 可動域
- COM軌跡
- バット速度
- バット角度
- スイング時間
- 運動連鎖
- 左右差
- 再現性
- 誤差
- RMSE
- ICC
- 相関係数
- Bland-Altman分析

検索語候補:

- joint angle
- range of motion
- kinematics
- kinetic chain
- trunk rotation
- pelvis rotation
- bat velocity
- swing velocity
- reliability
- validity
- RMSE
- ICC

### G. 比較対象・基準

- 既存の3Dモーションキャプチャとの比較
- IMUとの比較
- 手動アノテーションとの比較
- コーチ評価との比較
- 打球速度・飛距離・打率などのパフォーマンス指標との比較
- 群間比較: 熟練者 vs 初心者、成功 vs 失敗、強打者 vs 非強打者

検索語候補:

- validation
- concurrent validity
- reliability
- agreement
- comparison
- reference standard
- criterion validity

### H. 統計・評価方法

- 相関係数
- ICC
- RMSE
- MAE
- Bland-Altman分析
- t検定
- ANOVA
- 回帰分析
- 主成分分析
- クラスタリング
- 機械学習分類
- 時間正規化
- SPM（Statistical Parametric Mapping）

確認事項:

- 何を真値としているか
- 誤差が臨床的・実用的に許容される範囲か
- 統計的有意差と実用上の意味が分けて議論されているか
- サンプルサイズと検出力は十分か

### I. 研究デザイン

- 横断研究
- 妥当性検証研究
- 信頼性検証研究
- 症例研究
- 介入研究
- システマティックレビュー
- メタ分析
- 技術検証

優先順位:

1. 野球打撃そのものを対象にした研究
2. バット・ラケット・クラブを使う近接競技の研究
3. マーカーレス/スマホ/動画解析の妥当性検証研究
4. 歩行・リハビリなど、計測技術の参考になる研究
5. 一般的なバイオメカニクス方法論

### J. 実用性

- 現場で撮影できるか
- スマホ1台で成立するか
- 必要な照明・距離・角度は現実的か
- 解析に必要な時間はどの程度か
- コーチや学生が再現できるか
- 高価な装置が必要か
- プロジェクトの撮影環境と合うか

### K. 限界・バイアス

- 対象者が少ない
- 若年健常男性だけ
- 実験室条件に限定
- 競技動作ではなく単純動作
- 2D解析で奥行き方向が弱い
- 遮蔽が多い
- 終末可動域で誤差が増える
- カメラ位置に依存する
- フレームレート不足
- 真値の定義が弱い

### L. このプロジェクトへの関連度

各論文には、以下の関連度を付ける。

- `S`: 研究計画に直接使える。打撃動作、動画解析、妥当性検証のいずれかに強く関係する。
- `A`: 方法・指標・解析の一部が使える。
- `B`: 背景や周辺知識として有用。
- `C`: 今回の研究には遠いが、将来参考になる可能性がある。
- `除外`: テーマ・対象・方法が大きく外れる。

## 3. 検索クエリ作成ルール

検索式は、原則として次のブロックを組み合わせる。

```text
対象競技/動作 AND 計測方法 AND 指標/評価
```

例:

```text
("baseball batting" OR "baseball hitting") AND ("markerless motion capture" OR "pose estimation") AND (kinematics OR "joint angle")
```

```text
("batting swing" OR "hitting mechanics") AND ("smartphone" OR "video analysis") AND (validity OR reliability)
```

```text
("baseball swing" OR "softball swing") AND ("trunk rotation" OR "pelvis rotation") AND biomechanics
```

```text
("markerless motion capture" OR "AI motion analysis") AND ("joint angle" OR "range of motion") AND (validity OR reliability OR ICC OR RMSE)
```

近接競技まで広げる場合:

```text
("golf swing" OR "cricket batting" OR "tennis stroke") AND ("markerless motion capture" OR "pose estimation") AND biomechanics
```

## 4. 検索データベースの使い分け

- PubMed: 医療・リハビリ・バイオメカニクス寄り
- Google Scholar: 幅広く探索する初期検索
- Semantic Scholar: 関連論文・被引用関係の確認
- CrossRef: DOI・書誌情報の確認
- IEEE Xplore / ACM: 姿勢推定、コンピュータビジョン寄り
- SportsDiscus: スポーツ科学寄り
- J-STAGE / CiNii: 日本語研究・国内学会資料

## 5. スクリーニング手順

1. タイトルで粗く判定する。
2. Abstractで対象・方法・指標を確認する。
3. 研究目的に近いものを優先してPDFまたは本文を取得する。
4. `S/A/B/C/除外` の関連度を付ける。
5. `research_notes/未読/` にMarkdownメモを作る。
6. 重要論文は、引用文献と被引用文献をたどる。

## 6. Markdownメモの標準項目

```markdown
---
tags: [先行研究, 未読]
status: 未読
relevance: S/A/B/C/除外
date_added: YYYY-MM-DD
author: 著者
year: 発表年
title: 論文タイトル
doi: DOI
link: URL
pdf: ../PDFs/ファイル名.pdf
---

# 論文タイトル

## 1. 何の研究か

## 2. なぜ重要か

## 3. 対象者

## 4. 動作課題

## 5. 計測方法

## 6. 指標

## 7. 統計・評価方法

## 8. 主な結果

## 9. 限界

## 10. Project001への使いどころ

## 11. 次に読むべき文献
```

## 7. 採否判断ルール

採用候補にする条件:

- 打撃、スイング、投球、ラケット/クラブ動作などに関係する。
- 動画・スマホ・マーカーレス計測の精度検証に関係する。
- 関節角度、体幹回旋、骨盤回旋、COM、バット速度などの指標がある。
- 実験方法がProject001で再現可能、または参考になる。
- 統計・評価方法が明確である。

除外候補にする条件:

- 動作解析と関係が薄い。
- 対象動作がプロジェクトと大きく離れている。
- 方法が不明瞭で再現性が低い。
- 論文ではなく宣伝資料に近い。
- 数値や評価基準がほとんどない。

## 8. 読む優先順位

優先度1:

- 野球打撃のバイオメカニクス
- 打撃動作の3Dモーションキャプチャ研究
- 打撃における体幹・骨盤・下肢の運動連鎖

優先度2:

- スマホ動画・単眼カメラによる動作解析
- マーカーレスモーションキャプチャの妥当性・信頼性
- SPLYZA Motion、OpenPose、MediaPipeなどの検証研究

優先度3:

- ゴルフ、クリケット、テニスなど類似スイング動作
- リハビリや歩行分析における計測技術検証

優先度4:

- 一般的な姿勢推定・コンピュータビジョン手法
- 統計手法や信頼性評価の方法論

## 9. 検索Agentの出力ルール

検索Agentは、調査後に次を出力する。

- 検索したデータベース
- 使用した検索式
- ヒットした論文数
- 採用候補
- 除外候補と除外理由
- `research_notes/未読/` に作成したファイル一覧
- 次に広げるべき検索語

## 10. 現在の主要検索テーマ

初期テーマ:

- baseball batting biomechanics
- baseball swing kinematics
- markerless motion capture validation
- smartphone motion analysis validity
- pose estimation joint angle accuracy
- trunk pelvis separation batting
- lower limb kinematics batting
- bat swing velocity biomechanics

## 11. 注意点

- 「統計的に有意」と「研究で使える精度」は分けて読む。
- スマホやマーカーレスの研究では、撮影条件を必ず確認する。
- 打撃動作は遮蔽と高速運動が多いため、歩行研究の精度をそのまま当てはめない。
- 2D解析では、カメラに対して奥行き方向の動きが大きい指標を慎重に扱う。
- 妥当性研究では、参照標準が何かを必ず確認する。
- 関連度が高い論文は、引用文献と被引用文献をたどって検索を広げる。
