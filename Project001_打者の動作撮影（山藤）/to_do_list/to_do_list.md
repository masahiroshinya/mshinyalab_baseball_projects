# To-Do List & ルール管理

このファイルは、本プロジェクト（Project001_打者の動作撮影）におけるタスク管理、ならびに運用ルールの設定を行うための専用ドキュメントです。

---

## 運用ルール (Rules)

*ここにプロジェクトの進め方や、コーディング規約、ファイルの保存ルールなどを記載してください。*

- **[Rule]** 文献調査のまとめ・全体像は `previous_research/survey/yyyy-mm-dd-survey.md` に保存する。
- **[Rule]** 文献調査の個別ログは `previous_research/logs/yyyy-mm-dd.md` に保存する。
- **[Rule]** セッション（AIとの会話）のサマリーはプロジェクトルートの `logs/` フォルダに保存する。
- **[Rule]** タスクを登録する際は、誰が作成したかわかるように明記する（例: `[作成者: student]`, `[作成者: AI]`）。
- **[Rule]** 今後提示するColab用コードは、パスなどの変数に対してハードコーディングを避け、Colabのフォーム機能（`#@param`）などのUI実装形式にし、対象ドキュメントへ直接実装できる形で提示・記載すること。
- **[Rule]** (新規ルールを追加...)

---

## タスク一覧 (Tasks)

進捗を明確にするため、「毎日の日課（Daily）」「本日やるべきこと（Today）」「後日行うこと（Backlog）」の3つに分けて管理します。
毎日7:00以降に話しかけられた際にその日やるべきことをリスト化し、yyyy-mm-dd-todoの形でmdにして作成します。

### 🔄 毎日の日課 (Daily Routine)

修士の学生としての必須の自己研鑽タスクです。毎日必ず学習の時間を確保します。

- [ ] 英語の学習 `[作成者: student]`
- [ ] 数学の学習 `[作成者: student]`

### 📌 本日やるべきこと (Today's Tasks)

- [ ] **【Step 7: 進行中】キャリブレーション精度の向上（エラー画像の除外検証）**: 今回作成した `sandbox/Step07_キャリブレーション精度向上/実装ステップ.md` の「画像毎の誤差計算およびフィルタリング」コードをStep06のColabノートブックに組み込み、1.0px以上の悪い不良データを除外した状態で再計算（RMS改善）のテストを行う `[作成者: student]`
- [ ] **【Step 8: 進行中】ソフト2 キャリブレーション画像取得**: 同期済み映像からチェスボードのコーナー検出に成功するフレームをスライダーで選択し、キャリブレーション用の画像ファイルとして保存するスクリプトを Google Colab で開発する `[作成者: student]` `[追加日: 2026-04-15]`

### ✅ 最近完了したタスク

- [X] **【Step 8: 完了 2026-04-15】ソフト1 映像同期**: LED輝度変化のクロスコリレーションで映像間フレームオフセットを計算し、同期クリップを生成するスクリプトを Google Colab で実装・動作確認完了 `[作成者: student]`

### 📅 後日行うこと (Backlog / Future Tasks)

- [ ] **【Step 8: 未着手】時間同期精度の向上**: 先日の文献調査（ソフトウェア同期）を参考に、オーディオ同期を用いた概算同期に加えて、視覚的同期点（フラッシュ等）を用いた目視チューニングや、DTW・Pose2Simを利用したデータ波形/サブフレーム同期を検証する `[作成者: student]`
- [ ] YOLOv8（Step2〜4）で既に行っているバット・打者検出パイプラインに対して、バット特有の残像（モーションブラー）への耐性をさらに上げるためのTrackNetなどの応用可否を検討する `[作成者: AI]`
- [ ] **MATLAB学習 (Step 2以降)**: `Matlab_Learning/` にて、ステップに沿ってベクトル・行列の作成、データの計算、プロットの基本を習得する。 `[作成者: student]` `[追加日: 2026-04-16]`
- [ ] Pose2Simパイプライン全体でのマーカーレス精度評価ロジックを読み解く `[作成者: AI]`

#### 📑 必読の先行研究 (Required Reading)

`previous_research` 内での調査に基づき、本プロジェクトの実装や精度評価において特に重要となる原著論文の読解タスクです。

- [X] 【打撃バイオメカニクスの金字塔】Hitting a baseball: A biomechanical description (Welch et al., 1995) `[作成者: AI]` `[追加日: 2026-04-16]`
- [ ] 【スキルレベルによる動作比較】Differences in the kinematics of the baseball swing... (Inkster et al., 2011) `[作成者: AI]` `[追加日: 2026-04-16]`
- [ ] 【包括的解析の辞書】The Biomechanics of the Baseball Swing (Fortenbaugh, 2011) `[作成者: AI]` `[追加日: 2026-04-16]`
- [ ] 【超広角カメラの歪み補正】Calibration of Fisheye Lenses for 3D Reconstruction (Scaramuzza et al., 2006) `[作成者: AI]`
- [ ] 【システム同期と統合の教科書】Pose2Sim: An End-to-End Workflow for 3D Markerless Sports Kinematics (Pagnon et al., 2021) `[作成者: AI]`
- [ ] 【マーカレス精度の評価軸】Evaluation of 3D Markerless Motion Capture Accuracy Using OpenPose... (Nakano et al., 2020) `[作成者: AI]`
- [ ] 【高速な道具の軌跡追跡】TrackNet: A Deep Learning Network for Tracking High-speed and Tiny Objects... (Huang et al., 2019) `[作成者: AI]`
