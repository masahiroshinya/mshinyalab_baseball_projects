# 文献検索結果：Go/Stop 的な反応が求められる条件で、動作の時間的特性はどう変わるか

<!--
作成：2026-11-08、AI（Claude Opus 5.5）による文献検索・整理。依頼者：加藤和太郎。
修正：2026-11-09、確認の結果を反映（要約の [20] を [19] に、RT の根拠の [4] を [22] に替えた。[11] の説明を抄録〔PMID 9411024〕で確かめて書き直した。本研究の MT の結果を事後比較の有意な組に合わせて書いた）。
本ファイル内の番号は本ファイル限りの通し番号である。本文で引用する場合は 引用番号対応表.md 側で採番し直すこと。
反応時間（RT）を中心にした検索は ../反応課題_文献検索結果.md にある。本ファイルは、その続きとして「動作が始まったあとの時間（動作時間 MT、局面の時間、速度、力の立ち上がり）」に焦点を当てた。
-->

> **このファイルの範囲**　「Go/Stop 的な条件」は、**動作を止めるよう求められる可能性がある条件**（停止信号課題〔stop-signal task: SST〕、countermanding 課題、Go/No-go 課題、打撃の「見極め」）と広くとらえた。そのうえで、**反応時間（RT）だけでなく、動作時間（MT）・局面の時間・速度・力の時間経過**を報告している文献を優先した。

---

## 0. 要約

- **「止めるかもしれない」状況では、動作の開始（RT）が遅れるのはほぼ確立している**［[1](#ref-1)・[2](#ref-2)・[3](#ref-3)・[22](#ref-22)］。一方、**動作が始まったあとの時間（MT）がどう変わるかは、課題によって向きが分かれる。**
  - **MT が短くなる例**：手を伸ばす運動（Mirabella et al., 2008）では、RT が長い試行ほど MT が短いという**逆向きの関係**が全参加者で見られた［[1](#ref-1)］。決まった時刻に的を打つ課題（Pickavance et al., 2022、プレプリント）では、停止の可能性がある条件で**開始は約 95〜134 ms 遅れ、MT は約 33〜44 ms 短く**なり、それでも到達は遅れた［[2](#ref-2)］。**到達時刻の制約があると、開始の遅れを MT の短縮で取り戻そうとする**。
  - **MT が長くなる例**：優勢な反応を抑えて別の反応を出す Go/No-go の到達運動では、**RT も動作時間も長くなり、ピーク速度の時点が遅れた**［[5](#ref-5)］。停止信号課題の指の力の記録では、**開始が遅い試行ほど力の抜け方もゆっくり**で、それが停止の成功につながっていた［[8](#ref-8)］。
- **動作は途中まで出てから止められることがある**（部分反応・中断反応）。力や筋電図で見ると、停止に成功した試行でも、力や筋活動が途中まで立ち上がってから消える［[9](#ref-9)・[10](#ref-10)・[11](#ref-11)・[12](#ref-12)］。止める際には**拮抗筋がブレーキとして働く**［[13](#ref-13)・[14](#ref-14)］。
- **止められなくなる時点（point of no return）は、反応の過程のかなり遅い所にある**［[15](#ref-15)・[16](#ref-16)・[11](#ref-11)］。全身の動作では、**姿勢の準備の局面と主動作の局面で止められるかどうかが違う**［[17](#ref-17)・[18](#ref-18)・[19](#ref-19)］。
- **スポーツの動作**：野球のチェックスイングは「完全なスイング・抑制・部分反応・中断」に分類でき、単純な課題の抑制モデルで説明できる（Gray, 2009）［[23](#ref-23)］。野球型の打撃課題では、**時間の制約が 0.5 秒を切ると Go/No-go 判断の利点が失われるが、Go 試行で動作の開始を遅らせると判断の正確さが回復した**（Kobayashi & Kimura, 2022）［[24](#ref-24)］。ゴルフのパットでは、**ダウンスイングの時間が長い人ほど止めやすかった**［[25](#ref-25)］。
- **本研究への示唆（4 節）**：本研究では、Go/Stop 条件の MT が Simple 条件より約 57 ms 長く（Go/No-go 条件との差は有意でなかった）、MT の条件差はおもに HT（フック局面）の差によるもので、ピーク速度は条件で変わらなかった。これは、**到達時刻の制約がない課題では MT の短縮による埋め合わせが起きず**（[1](#ref-1)・[2](#ref-2) と対照的）、**動作の前半をゆっくり進めて止められる状態を長く保つ**調節（[5](#ref-5)・[8](#ref-8)・[17](#ref-17)・[18](#ref-18)・[19](#ref-19)・[25](#ref-25)）として説明できる可能性がある。

---

## 1. 検索方法

| 項目 | 内容 |
| :--- | :--- |
| 検索実施日 | 2026年11月8日 |
| データベース | PubMed（NCBI E-utilities 経由で抄録を取得） |
| 補助的情報源 | Web 検索、bioRxiv（全文）、J-STAGE |
| 主な検索語 | `stop-signal` / `countermanding` / `go/no-go` / `proactive inhibition` と、`movement time` / `movement duration` / `kinematics` / `velocity` / `force` / `EMG` / `reaching` / `gait initiation` / `baseball` / `batting` / `golf` / `point of no return` の組み合わせ |
| 既存の収集文献 | フォルダ 07（Kida 2005）、08（Nakamoto 2008）、09（Nasu 2020）、11（Verbruggen & Logan 2009）、90 の Muraskin 2015、`../反応課題_文献検索結果.md` と重ならないようにした |

**限界**
- システマティックレビューとしての網羅的な検索（件数の記録・選択基準の適用）はしていない。
- 内容は**原則として抄録に基づく**。全文を確認したのは Pickavance et al.（2022、bioRxiv）のみ。数値を引用する前に原典で確認すること。
- Pickavance et al.（2022）は**査読前のプレプリント**で、2026年11月の時点で学術誌での出版は確認できなかった（2026-11-09 に再確認：bioRxiv の出版版情報は「なし」で版は v1〔2022-06-02〕のみ。Crossref・PubMed の著者名検索、Web 検索でも、題名を変えたものを含めて出版版は見つからなかった）。
- 「バットスイングで Go/No-go（または Go/Stop）条件の MT・局面の時間を測った研究」は、今回の検索では見つからなかった（J-STAGE を含む）。本研究の新しさの根拠になりうる。

---

## 2. 文献の一覧

| # | 文献 | 動作 | 課題 | 時間的特性についての主な所見 |
| :-: | :--- | :--- | :--- | :--- |
| [1](#ref-1) | Mirabella, Pani & Ferraina (2008) *Cogn Neuropsychol* | 手の到達運動 | 単純 RT 課題 vs countermanding | 停止の文脈で RT が延びる。**RT と MT は逆向きに動く**（RT が延びれば MT は短い）。試行ごとにも負の相関 |
| [2](#ref-2) | Pickavance et al. (2022) *bioRxiv*（プレプリント） | 画面上のバットを動かして動く的を打つ | Go のみ vs **Go:Stop = 10:5** | 停止の可能性で**開始 +95〜134 ms、MT −33〜44 ms、到達 +54〜99 ms** |
| [3](#ref-3) | Ziri et al. (2024) *Psychophysiology* | 歩き始め | Go 確実 / Go 不確実 / NoGo | 不確実な条件で RT が遅れたが、**歩き始めのほかの変数は変わらなかった** |
| [4](#ref-4) | Mirabella et al. (2006) *Exp Brain Res* | 手の到達運動 | countermanding | 到達運動の SSRT は平均 206 ms。止められなくなる点は大脳半球間の伝達より後 |
| [5](#ref-5) | Angeli et al. (2021) *PLoS One* | 手の到達運動（手首の加速度計） | Go/No-go を改変（優勢な反応を抑えて別の反応） | 抑えたあとの反応は **RT・動作時間とも長く、ピーク速度の時点が遅い** |
| [6](#ref-6) | Benedetti et al. (2020) *Brain Sci* | マウスの軌跡 | 手がかり付き GNG と SST | 失敗試行の速度波形は、SST では一山（滑らか）が多く、GNG では多峰（修正あり）が多い |
| [7](#ref-7) | Wang, Liu & Li (2024) *Q J Exp Psychol* | キー押しの力 | GNG と SST | No-go の正しい差し控えでも力が出ている。止め方に「差し控え」と「取り消し」の 2 段階 |
| [8](#ref-8) | Ramawat et al. (2024) *Physiol Rep* | 指の力（ボタンを離す） | SST | **事前の力が大きいと開始が遅れ、力の抜け方も遅くなり、停止しやすい** |
| [9](#ref-9) | Nguyen et al. (2021) *Front Hum Neurosci* | 握力 | SST を改変 | 止めきれなかった力と力の立ち上がり速度は、停止信号の遅れ（SSD）とともに大きくなる |
| [10](#ref-10) | Raud, Thunberg & Huster (2022) *eLife* | 筋電図（部分反応 EMG） | SST | Go で立ち上がった筋活動が停止信号のあと急に消える。そのピークの潜時が停止の指標になる |
| [11](#ref-11) | McGarry & Franks (1997) *J Exp Psychol Hum Percept Perform* | 速い肘の伸展（EMG） | 停止信号 | EMG が出たあとでも動作は**中断されうる**。最大より小さい「部分的な」EMG を実行前の不完全な抑制と見なすと、止められなくなる点は **EMG 開始より前（前運動期の後半）**にあると推定（"phantom" point of no return） |
| [12](#ref-12) | Kudo & Ohtsuki (1998) *Exp Brain Res* | 速い肘の伸展（EMG） | 停止信号（45% の試行、ISI 0〜200 ms） | 途中で止めた動作の**振幅は停止信号からの時間とともに直線的に減り**、ピーク速度は振幅に比例 |
| [13](#ref-13) | Atsma et al. (2018) *J Neurosci* | 腕全体の到達運動（EMG） | countermanding | 停止信号に対して**拮抗筋が能動的にブレーキをかける**。その潜時は SSRT と共変 |
| [14](#ref-14) | Schultz et al. (2023) *J Cogn Neurosci* | 連続した動作を止める | 新しい停止課題（CMST） | 予定した停止では、**止める前に減速が大きい** |
| [15](#ref-15) | Osman, Kornblum & Meyer (1986) *J Exp Psychol Hum Percept Perform* | 選択反応 | countermanding | RT は「止められる段階」と「止められない段階」の和 |
| [16](#ref-16) | Logan (2015) *Q J Exp Psychol* | （総説） | 停止信号・タイピング | 止められなくなる点は反応系の遅い所にある。階層的な動作では階層ごとに別の点がある |
| [17](#ref-17) | Ilmane & LaRue (2011) *Acta Psychol* | 腕上げ（姿勢の予備調節 APA） | 停止信号 | 反応的な課題では APA と主動作が一体だが、予測的な課題では別々に止められる |
| [18](#ref-18) | Healey et al. (2026) *GeroScience* | 一歩踏み出す | 停止信号（踏み出し・足タップ・指） | **体重の最初の移動は止められないが、そのあと足を上げる局面は止められる**。高齢者は停止の予期で遅くなる程度が大きい |
| [19](#ref-19) | Fiori et al. (2025) *iScience* | 歩き始め（APA） | 停止信号 | 重心と支持基底面の関係に**これを越えると止められない生体力学的な閾値**がある |
| [20](#ref-20) | Koo & Kwon (2023) *Brain Sci* | 歩行の予定外の停止 | SST とは別に実施 | SSRT が短い人ほど、止める際の膝・足関節の角度・角速度が大きい |
| [21](#ref-21) | Elchlepp et al. (2016) *Cogn Psychol* | キー押し | 停止 / 無視 / 二重反応の文脈 | 停止への備えは、**刺激の検出・反応の選択・実行**の設定を事前に変える |
| [22](#ref-22) | Verbruggen & Logan (2009) *J Exp Psychol Hum Percept Perform* | キー押し | 停止信号の予告 | 停止の可能性だけで RT が延び、正確さは上がる（**フォルダ 11 に収集済み**） |
| [23](#ref-23) | Gray (2009) *J Exp Psychol Appl* | **野球の打撃**（シミュレーター） | チェックスイング | 結果を完全なスイング・抑制・部分反応・中断の 4 つに分け、抑制モデルで 20 名中 17 名を説明 |
| [24](#ref-24) | Kobayashi & Kimura (2022) *Commun Biol* | **野球型の打撃課題** | Go/No-go あり vs なし | 時間制約 0.5 秒未満で判断の利点が失われる。**Go 試行で開始を遅らせる**、または No-go で途中で止めると判断の正確さが回復 |
| [25](#ref-25) | You, van der Kamp & Savelsbergh (2024) *Hum Mov Sci* | **ゴルフのパット** | バックスイング終了 50 ms 後の停止信号 | **ダウンスイングの時間の変化が大きいほど、停止率・停止時間も増えた** |

---

## 3. テーマ別の整理

### 3-1. 止めるかもしれない文脈で、MT はどう変わるか（到達運動・打つ運動）

<a id="ref-1"></a>**[1] Mirabella, Pani & Ferraina (2008)**
- 18 名が同じ到達運動を、Go のみの RT 課題と、停止試行が混ざる countermanding 課題で行った。
- 停止試行の混ざる文脈で Go 試行の RT が延びることは以前から知られていたが、**MT についての報告はこれが最初**とされる。
- **RT と MT は逆向きの傾向**を示した（RT が減れば MT が増え、その逆も成り立つ）。全参加者で見られ、90% で有意。試行ごとにも中程度の負の相関。
- 著者らは、**同じ動作でも認知的な文脈によって運動プログラムが戦略的に変わり、動作中のフィードバック制御の程度が変わる**と解釈した。
- 注：抄録からは「countermanding 文脈で MT が短くなった」と読めるが、条件ごとの MT の値は全文で確認すること。

<a id="ref-2"></a>**[2] Pickavance, Mon-Williams, Mushtaq & Morehead (2022)**（bioRxiv、査読前）
- マウス・トラックパッドで画面上のバットを動かし、一定の速さで動く的を決まった地点で打つ。**Go だけの条件（Certain、15 試行）と、停止信号が混ざる条件（Uncertain、15 試行のうち 3 分の 1 が停止試行＝Go 10・Stop 5）**を比べた（本研究の Go:Stop = 10:5 と同じ比）。30 試行のブロックを 8 回。50 名。
- **課題の流れと時間の定義**（全文の Methods で確認）

  | 項目 | Pickavance et al.（2022） | 本研究 |
  | :--- | :--- | :--- |
  | Go の合図 | **的が動き始めること（1 回だけ）**。2 回目の Go はない | LED の Go cue。Go/Stop 課題では 0.25 秒後に 2 回目の刺激（Go か Stop） |
  | 停止信号 | 画面が急に昼の景色に切り替わる。最初は的が打つ地点に着く 320 ms 前に出し、停止に失敗すれば 50 ms 早く、成功すれば 50 ms 遅くする | Stop cue（1 回目の Go cue から 0.25 秒後に固定） |
  | 動作の開始（initiation） | バットが 0.75 単位動いた時点 | 動作開始（Onset） |
  | **MT** | **動作の開始から、バットが打つ面を横切るまで** | **動作の開始からピーク速度まで**（MT = t_peak − t_onset） |
  | 到達（arrival） | バットが打つ面を横切った時刻 | （該当なし。ボールがない素振り） |
  | 比べ方 | Certain と Uncertain の **Go 試行どうし** | 4 条件の Go 試行どうし |

  - **MT の始点はどちらも「動作の開始」で、2 回目の合図からの時間ではない**。違うのは終点で、Pickavance は「的に当たる面に着くまで」、本研究は「ピーク速度まで」。
  - Pickavance の MT は、**的に間に合わせるために縮める必要がある時間**である。これは、到達時刻の制約の有無で結果の違いを説明する 4 節の議論とも合う。
- 停止の可能性がある条件（Uncertain）の Go 試行では、Certain と比べて：
  - **動作の開始が遅れた**（実験の初め 95 ± 16 ms → 終わり 134 ± 21 ms）
  - **MT が短くなった**（44 ± 7 ms → 33 ± 8 ms）
  - **短縮は開始の遅れを埋めきれず、到達が遅れた**（54 ± 10 ms → 99 ± 16 ms）
- 解釈：停止への備えは、**反応の抑制（到達の遅れ）**と、**促進を遅らせる「待つ」戦略（短い MT で取り返す）**の両方からなる。参加者は開始と到達を遅らせたことを自覚していたが、その大きさは実際より小さく報告した。
- 本研究との違い：この課題には**的に当てる時刻の制約**がある。到達が遅れると失敗になるので MT を短くする動機がある。

<a id="ref-5"></a>**[5] Angeli et al. (2021)**
- 手首の 3 軸加速度計で到達運動を計測。優勢な反応（Dominant）と、それを抑えて別の反応を出す場合（Non-dominant）を比べた。19 名。
- 抑えたあとの反応は **RT も動作時間も長く、ピーク速度の時点が遅かった**。著者らは、動作中に修正するより**動作の計画に時間をかける**方略と解釈した。

<a id="ref-6"></a>**[6] Benedetti et al. (2020)**
- マウスの軌跡の速度波形を、一山（修正なし）か多峰（修正あり）かで分類。53 名。
- 止めきれなかった試行で、SST では一山が多く、手がかり付き GNG（事前の備えが主）では多峰が多い。**事前の備え（proactive control）が動作を滑らかでなくする**可能性。

<a id="ref-24"></a>**[24] Kobayashi & Kimura (2022)**（3-4 にも関係）
- 野球型の打撃課題で、ストライクゾーンの的は打ち（Go）、それ以外は打たない（No-go）。Go/No-go 判断のある条件とない条件を比べた。
- 時間の制約が 0.5 秒未満になると、判断の利点が失われた（主に動作の正確さではなく判断の正確さの低下による）。
- **Go 試行で動作の開始を遅らせる、または No-go 試行で動作を途中で取り消すと、判断の正確さが改善**した。時間が極端に短い状況では、**動作の進め方を変えることで判断を補う**。

### 3-2. 動作は途中まで出てから止まる（力・筋電図・速度で見る）

<a id="ref-7"></a>**[7] Wang, Liu & Li (2024)**：力を測れるキーボードで GNG と SST を比べた。No-go に正しく反応しなかった試行でも、基準より大きな力が出ていた。最初は「差し控え（restraint）」で抑え、失敗すると「取り消し（cancellation）」でキー押しの閾値の手前で止める、という 2 段階。SST の停止試行での力の平均振幅は、**事前の備え（proactive）**の指標になると考察。

<a id="ref-8"></a>**[8] Ramawat et al. (2024)**：ボタンを離す SST で人差し指の力を連続記録。**Go 信号前の力が大きい試行ほど、動作の開始が遅れ、力の抜け方もゆっくりになり、停止に成功しやすかった**。「動作の進み方の遅さ」が止めやすさと結びつく直接の例。

<a id="ref-9"></a>**[9] Nguyen et al. (2021)**：握力で「部分的な」失敗試行をとらえた。止めきれなかった力と力の立ち上がり速度は、停止信号が遅いほど大きい。

<a id="ref-10"></a>**[10] Raud, Thunberg & Huster (2022)**：部分反応 EMG（prEMG：Go で立ち上がった筋活動が、停止信号のあと完全な反応になる前に急に消えるもの）の方法論の総説的な研究。prEMG のピーク潜時は、モデルから推定する SSRT より停止の脳内機構を調べるのに適している。

<a id="ref-11"></a>**[11] McGarry & Franks (1997)**：速い肘の伸展の EMG から、動作は**EMG が出たあとでも中断されうる**（中断された反応）。一方、最大より小さい「部分的な」EMG も見られた。著者らは、中断された反応は反応の産出と停止の 2 つの独立な過程の競争（horse race）で説明でき、部分反応は 2 つの過程の間に漏れ（leakage）を認めれば説明できるとした。部分反応を「実行前の不完全な抑制」と見なす区別が正しければ、止められなくなる点は**前運動期の後半、つまり EMG 開始より前**にあることになる（題名の "phantom" point of no return）。抄録で確認（PMID 9411024）。

<a id="ref-12"></a>**[12] Kudo & Ohtsuki (1998)**：速い肘の伸展で、45% の試行に停止信号（Go から 0〜200 ms 後）。100 ms を越えると開始自体はほとんど止められない。**途中で止めた動作の振幅は、停止信号から筋活動開始までの時間とともに直線的に減り、ピーク速度は振幅に比例**。主動筋の最初の活動が減り、**拮抗筋の活動が増える**。

<a id="ref-13"></a>**[13] Atsma et al. (2018)**：腕全体の到達運動の停止では、動き始めたばかりの動作でも**拮抗筋が能動的にブレーキをかける**。その潜時は SSRT と個人内・個人間で共変し、停止試行が続くと短くなった。

<a id="ref-14"></a>**[14] Schultz et al. (2023)**：連続した動作を止める課題（CMST）。予定していた停止では、予定外の停止より早く止め始め、**止める前の減速が大きかった**。

### 3-3. 止められなくなる時点（point of no return）

<a id="ref-15"></a>**[15] Osman, Kornblum & Meyer (1986)**：RT は「止められる段階」と「止められない（バリスティックな）段階」の少なくとも 2 段階の和。後者は刺激の性質の影響を受けない。

<a id="ref-16"></a>**[16] Logan (2015)**：point of no return の総説。停止信号課題の研究からは、止められなくなる点は**反応系の遅い所**にある。タイピングのような階層的な動作では、**階層ごとに別の point of no return** があり、下位ほど動作へのかかわり（commitment）が強い。

<a id="ref-4"></a>**[4] Mirabella et al. (2006)**：到達運動の SSRT は平均 206 ms。止められなくなる点は半球間の伝達より後にある。

### 3-4. 全身の動作（姿勢の準備と主動作）

<a id="ref-3"></a>**[3] Ziri et al. (2024)**：歩き始めの Go/NoGo 課題（23 名）。Go が不確かな条件では**RT は遅れたが、歩き始めのほかの変数（運動学）は変わらなかった**。事前の抑制は「開始」に表れ、動作そのものには表れにくい例。

<a id="ref-17"></a>**[17] Ilmane & LaRue (2011)**：腕上げ動作の停止。単純反応の課題では姿勢の予備調節（APA）と主動作が一体（単一の運動指令）として出るが、予測的な課題では別々に止められる。**時間の制約によって局面の協調のしかたが変わる**。

<a id="ref-18"></a>**[18] Healey et al. (2026)**：一歩踏み出す停止信号課題（若年 27 名・高齢 29 名）。**踏み出す脚への最初の荷重は止められない（バリスティック）が、体重が支持脚に移るにつれて、足を上げる局面は外からの停止信号で切り離せる**。高齢者は動作が遅く、停止を予期したときの遅れが大きいが、停止の速さは若年者と同じで、事前の抑制に頼ることで停止の効率を保っている可能性。

<a id="ref-19"></a>**[19] Fiori et al. (2025)**：歩き始めの停止信号課題で、重心と支持基底面の関係に**これを越えると止められなくなる生体力学的な閾値**がある。動作の時刻（始め・止め）と身体の力学的な状態の両方が停止の成否を決める。

<a id="ref-20"></a>**[20] Koo & Kwon (2023)**：SSRT が短い人ほど、予定外に歩行を止めるときの膝・足関節の角度と角速度が大きい。指で測った抑制の能力が、全身の止め方と関係する。

### 3-5. 停止への備えの理論

<a id="ref-21"></a>**[21] Elchlepp et al. (2016)**：停止への備え（proactive inhibitory control）は、**刺激の検出・反応の選択・反応の実行**という下位の過程の設定を事前に偏らせる。二重反応の文脈でも同じような調節が起こる。

<a id="ref-22"></a>**[22] Verbruggen & Logan (2009)**：フォルダ 11 の `03_notes.md` を参照。停止の可能性だけで RT が延び、正確さは上がる（反応の閾値を上げる方略）。停止の文脈では非決定時間（運動の実行を含む）も延びており、**運動出力そのものの抑制**も示唆される。

### 3-6. スポーツの動作

<a id="ref-23"></a>**[23] Gray (2009)**：野球のチェックスイングの抑制モデル。3 種の抑制の手がかり（打ち出し角が範囲外、予測と実際の軌道の早い時期のずれ、遅い時期のずれ）から、スイングの結果を**完全なスイング・抑制されたスイング・部分反応・中断されたスイング**の 4 つに分ける。高精度の打撃シミュレーターで 20 名の打者の割合を 17 名で説明できた。**単純な課題の抑制モデルが、多段階の複雑な動作にも当てはまる**。

<a id="ref-25"></a>**[25] You, van der Kamp & Savelsbergh (2024)**：ゴルフのパットで、バックスイングの終わりから 50 ms 後に音の停止信号を出し、ダウンスイングを止めさせた。教示の介入（意識的な動作への関与を増やす / 減らす）は停止率・停止時間を直接は変えなかったが、媒介分析では、**ダウンスイングの時間の変化が大きいほど、停止率と停止時間の増加が大きかった**。止めやすさは動作の運動学（時間）を通して変わる。

**Kobayashi & Kimura (2022)** は 3-1 の [24] を参照。

**既存の収集文献との関係**：Nasu et al.（2020、フォルダ 09）はスイングの開始の時刻を「動作を実行するという最初の判断」の指標として扱っている。Muraskin et al.（2015、90 の未引用）と Nakamoto & Mori（2008、フォルダ 08）は、野球選手の Go/No-go 判断を脳波・RT で扱っている。

---

## 4. 本研究（Go/Stop 条件での MT・HT の延長）への示唆

本研究の 10 名の結果（`Experiments/Main experiments/03_Analysis/x8_StatTable/RM-ANOVA_2026-1103_結果まとめ.md`、ポスター ver.02）：MT の平均は Simple（556 ms）< Go/No-go（589 ms）< Go/Stop（613 ms）< Free（721 ms）の順だった。事後比較で有意だったのは、**Free と他の 3 条件の差（108〜165 ms）と、Go/Stop と Simple の差（約 57 ms）**で、Simple と Go/No-go（p = .085）、Go/No-go と Go/Stop（p = .130）の差は有意でなかった。**MT の条件差はおもに HT（フック局面）の差によるもので、ピーク速度は条件で変わらなかった**。以下は文献から考えられる解釈の候補で、確かめるべき仮説として挙げる。

1. **「RT が延び MT は短くなる」先行研究との違いをどう説明するか**
   - 到達運動［[1](#ref-1)］や時刻の決まった打つ課題［[2](#ref-2)］では、停止の文脈で MT が**短く**なった。本研究では Go/Stop 条件の MT が Simple 条件より**長く**なっており、向きが逆である。
   - 違いの候補は**到達時刻の制約の有無**。[2] では的に当てる時刻が決まっているため、開始の遅れを MT で取り戻す必要がある。本研究の課題（LED の合図でスイングする）には、ボールに当てる時刻の制約がないので、取り戻す必要がない。Discussion でこの違いを明示すると、先行研究との矛盾に見える点を説明できる。
   - 本研究の中でも、Go cue がなく任意のタイミングで振る Free 条件（自由スイング条件）の MT が最も長かった。**時間の制約がゆるいほど MT が長くなる**という傾向は、この説明と矛盾しない。
   - 本研究の Go:Stop = 10:5 は [2] とまったく同じ比で、比較の相手として使いやすい（ただしプレプリントである点に注意）。

2. **前半の局面（HT）だけが延び、ピーク速度は変わらない**
   - 力の研究［[8](#ref-8)］では、動作の進み方が遅いほど止めやすい。ゴルフ［[25](#ref-25)］でも、ダウンスイングの時間が長いほど止めやすかった。
   - 全身の動作では、局面によって止められるかどうかが違う［[17](#ref-17)・[18](#ref-18)・[19](#ref-19)］。HT を「まだ止められる局面」、それ以降を「止められなくなる局面」と見ると、**止められる局面を長く保ち、止められなくなってからは通常どおり振る**という調節として説明できる可能性がある。これはポスターの考察 ①（Go/Stop で HT に止めやすくする調節が表れた）を支える文献になる。
   - 歩き始め［[3](#ref-3)］では RT だけが遅れ動作は変わらなかったので、**動作の中に調節が表れるかは動作の種類による**。スイングで HT に表れたことは、それ自体が新しい所見として書ける。

3. **事前の備えは実行の段階にも及ぶ**
   - Verbruggen & Logan（2009）［[22](#ref-22)］の非決定時間の延長、Elchlepp et al.（2016）［[21](#ref-21)］の「実行の設定も偏る」という主張は、「停止への備えが RT だけでなく MT（HT）にも表れる」という本研究の結果の理論的な背景になる。

4. **打撃の文脈での位置づけ**
   - Gray（2009）［[23](#ref-23)］のチェックスイングの 4 分類（特に「部分反応」「中断されたスイング」）は、本研究の Stop 試行のスイングを分類する枠組みとして使える可能性がある。
   - Kobayashi & Kimura（2022）［[24](#ref-24)］は、Go/No-go の判断が必要なときに**開始を遅らせることが判断の正確さを高める**ことを示しており、本研究の RT の延長に機能的な意味づけを与えうる。

5. **今後の解析の候補**（文献から示唆されるもの）
   - 試行ごとの RT と MT（HT）の相関［[1](#ref-1)］：Go/Stop で負の相関（埋め合わせ）か、正の相関（全体がゆっくり）かを確かめる。
   - Stop 試行で、どの局面まで進んでから止まったか（部分反応の分析）［[10](#ref-10)・[12](#ref-12)・[23](#ref-23)］。
   - 止める際の拮抗的な動き（ブレーキ）の時刻［[13](#ref-13)］。

---

## 5. 文献リスト

1. Mirabella, G., Pani, P., & Ferraina, S. (2008). Context influences on the preparation and execution of reaching movements. *Cognitive Neuropsychology*, 25(7–8), 996–1010. https://doi.org/10.1080/02643290802003216
2. Pickavance, J. P., Mon-Williams, M., Mushtaq, F., & Morehead, J. R. (2022). Proactive inhibition of goal-directed movements involves explicit changes to movement planning. *bioRxiv*（プレプリント）. https://doi.org/10.1101/2022.06.01.494317
3. Ziri, D., Hugueville, L., Olivier, C., Boulinguez, P., Gunasekaran, H., Lau, B., Welter, M. L., & George, N. (2024). Inhibitory control of gait initiation in humans: An electroencephalography study. *Psychophysiology*, 61(11), e14647. https://doi.org/10.1111/psyp.14647
4. Mirabella, G., Pani, P., Paré, M., & Ferraina, S. (2006). Inhibitory control of reaching movements in humans. *Experimental Brain Research*, 174(2), 240–255. https://doi.org/10.1007/s00221-006-0456-0
5. Angeli, A., Valori, I., Farroni, T., & Marfia, G. (2021). Reaching to inhibit a prepotent response: A wearable 3-axis accelerometer kinematic analysis. *PLoS ONE*, 16(7), e0254514. https://doi.org/10.1371/journal.pone.0254514
6. Benedetti, V., Gavazzi, G., Giovannelli, F., Bravi, R., Giganti, F., Minciacchi, D., Mascalchi, M., Cincotta, M., & Viggiano, M. P. (2020). Mouse tracking to explore motor inhibition processes in go/no-go and stop signal tasks. *Brain Sciences*, 10(7), 464. https://doi.org/10.3390/brainsci10070464
7. Wang, Z., Liu, X., & Li, X. (2024). Unravelling the dynamics of response force: Investigating motor restraint and motor cancellation through go/no-go and stop-signal tasks. *Quarterly Journal of Experimental Psychology*, 77(11), 2199–2213. https://doi.org/10.1177/17470218231219867
8. Ramawat, S., Marc, I. B., Di Bello, F., Bardella, G., Ferraina, S., Pani, P., & Brunamonti, E. (2024). Force monitoring reveals single trial dynamics of motor control in a stop signal task. *Physiological Reports*, 12(22), e70127. https://doi.org/10.14814/phy2.70127
9. Nguyen, T. V., Hsu, C. Y., Jaiswal, S., Muggleton, N. G., Liang, W. K., & Juan, C. H. (2021). To go or not to go: Degrees of dynamic inhibitory control revealed by the function of grip force and early electrophysiological indices. *Frontiers in Human Neuroscience*, 15, 614978. https://doi.org/10.3389/fnhum.2021.614978
10. Raud, L., Thunberg, C., & Huster, R. J. (2022). Partial response electromyography as a marker of action stopping. *eLife*, 11, e70332. https://doi.org/10.7554/eLife.70332
11. McGarry, T., & Franks, I. M. (1997). A horse race between independent processes: Evidence for a phantom point of no return in the preparation of a speeded motor response. *Journal of Experimental Psychology: Human Perception and Performance*, 23(5), 1533–1542. https://doi.org/10.1037/0096-1523.23.5.1533
12. Kudo, K., & Ohtsuki, T. (1998). Functional modification of agonist-antagonist electromyographic activity for rapid movement inhibition. *Experimental Brain Research*, 122(1), 23–30. https://doi.org/10.1007/s002210050487
13. Atsma, J., Maij, F., Gu, C., Medendorp, W. P., & Corneil, B. D. (2018). Active braking of whole-arm reaching movements provides single-trial neuromuscular measures of movement cancellation. *Journal of Neuroscience*, 38(18), 4367–4382. https://doi.org/10.1523/JNEUROSCI.1745-17.2018
14. Schultz, K. E., Denning, D., Hufnagel, V., & Swann, N. (2023). Stopping a continuous movement: A novel approach to investigating inhibitory control. *Journal of Cognitive Neuroscience*, 35(7), 1108–1132. https://doi.org/10.1162/jocn_a_01998
15. Osman, A., Kornblum, S., & Meyer, D. E. (1986). The point of no return in choice reaction time: Controlled and ballistic stages of response preparation. *Journal of Experimental Psychology: Human Perception and Performance*, 12(3), 243–258. https://doi.org/10.1037/0096-1523.12.3.243
16. Logan, G. D. (2015). The point of no return: A fundamental limit on the ability to control thought and action. *Quarterly Journal of Experimental Psychology*, 68(5), 833–857. https://doi.org/10.1080/17470218.2015.1008020
17. Ilmane, N., & LaRue, J. (2011). Postural and focal inhibition of voluntary movements prepared under various temporal constraints. *Acta Psychologica*, 136(1), 1–10. https://doi.org/10.1016/j.actpsy.2010.08.005
18. Healey, R., Wells, M. J., Salomoni, S. E., Puri, R., Hinder, M. R., & St George, R. J. (2026). The stop signal stepping task: How action cancellation commands disrupt step initiation in young and healthy older adults. *GeroScience*（オンライン先行公開）. https://doi.org/10.1007/s11357-026-02186-y
19. Fiori, L., Ramawat, S., Marc, I. B., Giuffrida, V., Ranavolo, A., Draicchio, F., Pani, P., Ferraina, S., & Brunamonti, E. (2025). Balancing postural control and motor inhibition during gait initiation. *iScience*, 28(3), 111970. https://doi.org/10.1016/j.isci.2025.111970
20. Koo, D. K., & Kwon, J. W. (2023). Biomechanical analysis of unplanned gait termination according to a stop-signal task performance: A preliminary study. *Brain Sciences*, 13(2), 304. https://doi.org/10.3390/brainsci13020304
21. Elchlepp, H., Lavric, A., Chambers, C. D., & Verbruggen, F. (2016). Proactive inhibitory control: A general biasing account. *Cognitive Psychology*, 86, 27–61. https://doi.org/10.1016/j.cogpsych.2016.01.004
22. Verbruggen, F., & Logan, G. D. (2009). Proactive adjustments of response strategies in the stop-signal paradigm. *Journal of Experimental Psychology: Human Perception and Performance*, 35(3), 835–854. https://doi.org/10.1037/a0012726（フォルダ 11 に収集済み）
23. Gray, R. (2009). A model of motor inhibition for a complex skill: Baseball batting. *Journal of Experimental Psychology: Applied*, 15(2), 91–105. https://doi.org/10.1037/a0015591
24. Kobayashi, A., & Kimura, T. (2022). Compensative movement ameliorates reduced efficacy of rapidly-embodied decisions in humans. *Communications Biology*, 5(1), 294. https://doi.org/10.1038/s42003-022-03232-z
25. You, Y., van der Kamp, J., & Savelsbergh, G. (2024). The effects of conscious movement investment on inhibiting a golf stroke. *Human Movement Science*, 96, 103248. https://doi.org/10.1016/j.humov.2024.103248

---

## 6. 優先して原典を集めたい文献

本研究の Discussion（MT・HT の延長の解釈）に直接使えそうな順。

1. **Pickavance et al. (2022)** ［[2](#ref-2)］：Go:Stop = 10:5 が同じで、開始・MT・到達を分けて報告。全文は bioRxiv で無料。出版版が出ていないか、引用前に再確認する。
2. **Mirabella et al. (2008)** ［[1](#ref-1)］：停止の文脈での MT を最初に報告。条件ごとの MT の値を全文で確認する。
3. **Gray (2009)** ［[23](#ref-23)］：打撃の抑制モデル。Stop 試行のスイングの分類に使える。
4. **Kobayashi & Kimura (2022)** ［[24](#ref-24)］：野球型の課題。オープンアクセス。
5. **You et al. (2024)** ［[25](#ref-25)］：スイング動作の時間と止めやすさの関係。
6. **Healey et al. (2026)** ［[18](#ref-18)］・**Ramawat et al. (2024)** ［[8](#ref-8)］：局面ごとの止めやすさ、動作の遅さと止めやすさ。

収集した文献は、`00_README_文献整理ルール.md` に従い、本文で引用する時点で引用番号のフォルダに、引用しないものは `90_未引用_本文で引用していない文献/` に置く。
