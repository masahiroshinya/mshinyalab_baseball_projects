# 図の種類（作成方針と既定値）

状態：試行中（2026-10-16 に figure-recipes/ として作成、2026-10-19 に図の種類ごとのフォルダに組み替え）。
方針の本体は [docs/figure-style.md](../docs/figure-style.md)（入口）、[docs/figure-panel-style.md](../docs/figure-panel-style.md)（パネル単位）、[docs/figure-assembly-style.md](../docs/figure-assembly-style.md)（統合）。

<!-- 更新の注記：
  - 図の種類ごとのフォルダには、その種類に固有の作成方針（recipe.md）、既定値の上書き（defaults.json）、ダミーデータの例（example_*.m）を置く。一般的な方針は docs/ の文書に書く。
  - 1 つの図だけへの個別の注文（軸範囲の変更など）は、recipe.md にも defaults.json にも書かない（docs/figure-style.md の「個別の注文の扱い」）。
  - recipe.md と既定値は、まとまりのある単位の作業が終わった後に更新する。AI と作業したセッションでは、セッションをまとめるときに AI が提案し、ユーザーが了承してから書く（docs/figure-style.md の「更新のしかた」）。ユーザーが明示的に指示した場合は、その指示に従ってすぐに書く。
  - 新しい種類を作ったら、下の一覧に 1 行追加する。
  - 複数の種類に共通する手順が出てきたら、一般化して docs/ の文書へ移し、recipe.md からはその節を参照する。
-->

## 一覧

| フォルダ | 対象の図 | 例（ダミーデータ） | 作成日 |
|---|---|---|---|
| [timeseries/](timeseries/recipe.md) | 時系列（平均の線、平均 ± SD・信頼区間の帯、時刻のイベントを示す縦線、凡例） | example_kinematic_sequence.m（投球の運動連鎖）、example_running_grf.m（走行の床反力） | 2026-10-19 |
| [bar-points/](bar-points/recipe.md) | 棒グラフと個人の値の点（個人を結ぶ線は任意）、誤差棒、有意差記号 | example_jump_height.m（条件ごとの跳躍高） | 2026-10-19 |
| [scatter/](scatter/recipe.md) | 散布図（群ごとの点、回帰直線と信頼区間の帯は任意） | example_ball_speed_scatter.m（体幹の回旋角速度と球速） | 2026-10-19 |

複数パネルの並べ方（幅の割り振り、余白の揃え方）は、方針が決まったら docs/figure-assembly-style.md に書く。並べ方の型が増えるようなら、このフォルダとは別に `layouts/` を作る。

## 既定値（defaults.json）

- 全種類に共通の既定値は [defaults.json](defaults.json) に置く。種類ごとのフォルダの defaults.json には、共通の値と違うもの、その種類だけで使うものを書く。
- MATLAB では `createPanelAxes('<種類>')`（内部で `loadFigureDefaults('<種類>')`）が、共通の値と種類の値を合わせた構造体 `style` を返す。構造体の項目（例：`fontSizePt`）は、その中の項目ごとに上書きされる。
- 1 つの図だけで違う値にするときは、その図のスクリプトで `style` の値を書き換える（defaults.json は変えない）。

共通の既定値（2026-10-19）：

| 項目 | 値 | 意味 |
|---|---|---|
| `columnWidthMm` | single 90、double 190 | 図全体の幅（段の幅）[mm]。docs/figure-assembly-style.md の 4 節 |
| `figureSizeCm` | [8, 6] | 1 パネルの MATLAB の図の大きさ [cm] |
| `innerPositionCm` | [1.6, 1.1, 6.0, 4.5] | 軸の枠の位置と大きさ [cm]（図の左下が原点） |
| `fontName` | Arial | |
| `fontSizePt` | panelLabel 9.75、axisLabel 9、tickLabel 7.5 | 文字の大きさ [pt]。根拠は docs/figure-panel-style.md の 2 節 |
| `lineWidthPt` | 1 | 軸線・データの線の太さ [pt] |
| `markerSizePt` | 4 | 点の大きさ（MATLAB の MarkerSize）[pt] |
| `colours` | Okabe-Ito の blue・vermilion・bluish green・orange | 系列の色の順（RGB、0〜255） |

種類ごとの既定値は各フォルダの recipe.md の「既定値」に書く。

## 新しい種類の追加のしかた

1. `figure-types/<種類>/` を作る（名前は英語の小文字とハイフン）。
2. `defaults.json`（共通と違う値だけ。なければ `{}`）、`example_<内容>.m`（ダミーデータの例）、`recipe.md`（下の雛形）を置く。
3. `make_all_examples.m` に例を加え、上の一覧に 1 行追加する。

## recipe.md の雛形

該当しない項目は「なし」と書く。

```markdown
# （図の種類の名前）

状態：（試行中／確定）。作成：YYYY-MM-DD。

## 1. 対象の図

どのような図か。含みうる要素（任意のものは「任意」と書く）。

## 2. 既定値

defaults.json の項目と値、その理由。

## 3. 作図と成分のページ

MATLAB での作図の要点（描く順、使う関数）と、成分（サブレイヤー）の分け方。docs/figure-panel-style.md の 3・5 節と違う点を中心に書く。

## 4. Affinity で加える注釈

注釈の種類（JSON の annotations の type）と置き方。

## 5. 方針との違い

どの文書のどのルールの例外か。例外にする理由。

## 6. 確認すること

位置合わせ、線幅・文字サイズ、書き出した PDF での確認など。

## 7. 経緯

いつ、どの図で生じたか。使って変わった点（日付つき）。
```
