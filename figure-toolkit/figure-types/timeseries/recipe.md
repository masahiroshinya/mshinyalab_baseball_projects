# 時系列（timeseries）

状態：試行中。作成：2026-10-19。

## 1. 対象の図

横軸が時間（または動作周期の %）の波形。含みうる要素：

- 系列ごとの平均の線
- 平均 ± SD や信頼区間の帯（任意）
- 時刻のイベントを示す縦線と、その名前（任意。例：FC、MER、BR）
- 凡例（任意）
- Affinity で加える注釈（任意。局面を示す両矢印と文字、ピークを指す矢印と文字）

## 2. 既定値

[defaults.json](defaults.json)（共通の既定値は [../defaults.json](../defaults.json)）：

| 項目 | 値 | 意味 |
|---|---|---|
| `bandOpacity` | 0.25 | 帯の不透明度（MATLAB の FaceAlpha）。線と同じ系列の色を使い、透明度で淡くする |
| `eventLineColour` | [102, 102, 102] | イベント線と、その名前の色（黒 60 % の灰色）。データの線と区別するため |

## 3. 作図と成分のページ

- 描く順（背面から）：帯、平均の線、イベント線。凡例は、データのない代理の線（`plot(ax, NaN, NaN, …)`）で作る（データのページを切り替えても凡例の見た目が変わらないように）。
- イベント線は `xline(ax, t, '--', name, …)` で描き、名前の揃え（`LabelHorizontalAlignment`）はイベントごとに、隣の線の名前と重ならない側にする。
- 成分（サブレイヤー）：`events`、`bands <系列>`、`lines <系列>`、`axes`（axes lines・tick labels・axis labels に分かれる）、`legend`。帯のサブレイヤーは線より背面にする。
- 縦軸：符号付きの量（角速度など）は 0 を中心に正負対称にする（docs/figure-panel-style.md の 1 節）。

## 4. Affinity で加える注釈

- `arrow`：両矢印（局面）または片矢印（ピークを指す）。文字は矢印の上、または指定の側に置く。文字が矢印の間に入らないときは、矢印を一段下げ、文字を矢印の外に置く（例：example_kinematic_sequence.m の Acceleration）。
- 位置はデータ座標で JSON に書く（docs/figure-panel-style.md の 2 節、affinity/compose/compose_single_panels.js の手順 7）。

## 5. 方針との違い

なし。

## 6. 確認すること

- イベント線の名前同士、名前とデータの線が重ならないこと。
- MATLAB が破線で書き出した線（イベント線）は、Affinity では塗りの図形として取り込まれるので、Panel style で線種を変えられない（docs/adjustable-properties.md）。線種を変えるときは MATLAB で変える。

## 7. 経緯

- 2026-10-18：ダミーデータの例 2 つ（投球の運動連鎖、走行の床反力）で作成。
- 2026-10-19：figure-toolkit への整理で、図の種類 timeseries としてまとめた（ユーザーの指定：信頼区間の帯や時刻のイベントを示す縦線を含む可能性がある）。
