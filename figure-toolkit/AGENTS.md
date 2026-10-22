# figure-toolkit の作業規約（AI エージェント向け）

このファイルは `figure-toolkit/` とその配下での作業に適用する。Claude、Codex など、AI エージェントの種類を問わない。リポジトリに置いた場合は、リポジトリのルートの AGENTS.md（コーディング規約、ログ、コミット）も併せて参照する。

人間向けの導入手順と使い方は [README.md](README.md)。作図の方針の入口は [docs/figure-style.md](docs/figure-style.md)。

## 1. 作図の作業のルール

- この toolkit は、ユーザーの研究用のプロジェクトのフォルダの中に置かれ、AI はそのプロジェクトのフォルダで起動されることが多い。toolkit のフォルダは作業の場所ではない。
- 成果物（作図スクリプト、完成図、チュートリアルの作業のファイル）の保存先は、ユーザーが指定する。明示的な指定がなければ、作る前に必ず尋ねる。尋ねるときは、保存先の案を示す（例：「図を作るフォルダを `<原案のフォルダ>/<図の名前>/` に作ってよいですか？」）。了承か指定の返事があるまで、ファイルを作らない。
- 図は、まず既定の作業の流れ（docs/ の方針、figure-types/ の recipe.md と defaults.json、matlab/ と affinity/ の共通の関数・スクリプト）で作る（1 回目の出力）。
- 1 回目の出力の後の個別の注文（特定の図の軸範囲など）は、その図のスクリプトとドキュメントにだけ反映する。明示的な指示がない限り、既定の作業の流れ（方針の文書、recipe.md、defaults.json、共通の関数・スクリプト）は変更しない。共通の既定値と違う値は、その図のスクリプトで `style` を書き換えて指定する（docs/figure-style.md の「個別の注文の扱い」）。
- 既定値の変更はユーザーが指示する。ユーザーが図ごとに明示的に指定した値（段の種類、図の高さなど）は、それに従う。
- 方針の文書と recipe.md は、まとまりのある単位の作業が終わった後に更新する。セッションをまとめるときに、更新の候補を提案し、ユーザーが了承してから書く。ユーザーが明示的に指示した場合は、その指示に従う。
- 明示的な指示がない限り、シルエットの作成や実写写真の加工（画像トレース、人物の切り抜き、イラスト化など）は行わない。必要になりそうな場合も、提案・実行せず、ユーザーに確認する。
- ファイルの記述もチャットの応答も、比喩・レトリックを避けて客観的に書く。
- チャットの応答（作業の報告・質問・途中経過の知らせを含む）は日本語で書く。ユーザーから明示的な指示がある場合は、その指示に従う。リポジトリに置いた場合は、ルートの AGENTS.md の指定に従う。

## 2. Affinity を操作するときのルール

- 接続には `tools/affinity-mcp.mjs`（Node.js 18 以上、標準モジュールだけ）を使う。使い方はファイルの冒頭。figure-toolkit のフォルダで実行する。
- MCP 経由のスクリプトが読み書きできるのはデスクトップの中だけ。入力は `affinity_mcp_work/input/`、.af は `affinity_mcp_work/panels/`、書き出しは `affinity_mcp_work/export/` に置く（`run` の後、クライアントが `AFFINITY_COLLECT_DIR` へ移す。指定がなければ移さずに export/ に残す）。
- ユーザーが開いているドキュメントを変更・保存・クローズしない。AI が開いたドキュメントだけを、題名または `sessionUuid` で特定して操作・クローズする。
- Affinity は AI が起動・終了・再起動しない。起動していなければ（クライアントが接続できなければ）、ユーザーに起動を頼み、起動したと返事があってから続ける。画面の状態をユーザーが把握できるようにするためと、Affinity が正常に終了しなかった後は MCP の設定（「デスクトップ上のファイルへのアクセス」）がオフに戻っていることがあり、権限の設定は人が確かめる必要があるため。
- 組み立てのスクリプト（affinity/compose/）は、作り直す前に同じ名前の図の文書を閉じる。保存していない変更がある文書は閉じずに止まる（ユーザーが Affinity で手を加えた可能性がある）。止まったときは、変更を残すなら別の名前で保存して閉じてもらうか、変更を破棄してよいかを確かめてからやり直す。同じ名前で保存してもらってはいけない（組み立てのスクリプトは `affinity_mcp_work/panels/<図の名前>.af` に保存し直すので、組み立て直すと上書きされる）。
- 1 回目の出力の後にチャットで修正を頼まれたときは、その図の作図スクリプトを直して、組み立てと確認（4 節の 4〜9）をやり直す。依頼による軸範囲・横位置の変更などで `compareFigureData` が NG になる場合は、依頼による差であることを確かめて報告する。
- ダイアログ（`runModal`）や `alert` を MCP 経由で実行しない（ユーザーの応答待ちになる）。Panel style は `globalThis.panelStyleTest` を定義して、ダイアログを出さずに確認する（6 節）。
- Affinity の AI 機能（Canva AI スタジオ）は、明示的な指示がない限り使わない（AI 利用枠を消費する）。
- SDK ヒントの共有（MCP の `add_sdk_hint`）は、明示的な指示がない限り使わない（試行内容が Affinity 側へ送られる）。検索（`search_sdk_hints`）は使ってよい。
- Affinity に送るスクリプトは、ファイル作成用のツールで書く。シェルのヒアドキュメントで書くと `\` が失われることがある。
- パスは OS に依存しない書き方にする：Affinity のスクリプトは `joinPath`（`app.userDesktopPath` から区切りを判断する。affinity/compose/ の冒頭）、MATLAB は `toolkitPaths()` と `fullfile`、Python は `pathlib`。

## 3. 新しい環境での導入

ユーザーが README.md の 2.1 節（人が行う設定）を済ませた後に「導入してください」と頼まれたら、次の順に行い、各段階の結果を報告する。

- ソフトウェアのインストール、MATLAB の設定の変更、環境変数の設定、作業フォルダの作成、Panel style の登録、導入の確認で作ったものの削除は、ユーザーの了承を得てから行う。
- README.md の 2.1 節の設定（Affinity のスクリプトと MCP の設定、パレットの読み込み）は、AI が代わりに行わない。AI には行えないうえ、権限を与える設定なのでユーザーが判断する。足りない設定があれば、2.1 節のどれかを示して頼む。
- ユーザーへの報告では、この節の番号を使わず、README.md の 2.2 節の項目の名前（必要なソフトウェア、MATLAB の設定、Affinity との接続と例の図での確認、Panel style の登録）を使う。
- `<作業フォルダ>` は、Affinity のデスクトップの `affinity_mcp_work` の絶対パス（3 で確かめる）。

1. 必要なもの：`node --version`（18 以上）、`python --version`、`python -c "import pypdf"`。足りないものは、了承を得てから入れる（例：winget、`pip install pypdf`）。
2. MATLAB のパス：了承を得てから、`userpath` のフォルダの startup.m に `addpath('<toolkit>/matlab')` の行を加える（startup.m があれば、既存の行は変えずに 1 行加える）。`savepath` は MATLAB 全体のパスの設定を書き換えるので使わない。続けて `matlab -batch "disp(toolkitPaths())"` で、関数が使えることを確かめる。
3. MCP の接続と作業フォルダの場所：`node tools/affinity-mcp.mjs run affinity/compose/check_connection.js`（接続と、作業フォルダの読み込みを確かめる。作業フォルダは 4 で作るので、この時点では desktop が NG でよい）。接続できなければ、README.md の 2.1 節の 3（MCP の有効化と再起動）を確かめてもらう。ほかの原因は README.md の 4 節（FAQ）。
   - desktop の行に出る場所（Affinity が使う作業フォルダ）と、2 の `toolkitPaths()` の `work`（MATLAB・Python・Node が使う作業フォルダ）が同じかを確かめる。
   - 違う場合（Windows でデスクトップを OneDrive に移している場合など）は、了承を得てから、環境変数 `AFFINITY_WORK_DIR` に Affinity 側の場所を設定する。Windows はユーザーの環境変数（`setx AFFINITY_WORK_DIR "<場所>"`）、Mac はシェルの設定ファイル（`~/.zshrc` の `export`）と startup.m の `setenv`（Dock から起動した MATLAB はシェルの設定を読まないため）。設定は、その後に起動したプログラムから有効になるので、それまではコマンドごとに指定する。Affinity 側のスクリプトはこの変数を読まず、常にデスクトップの `affinity_mcp_work` を使う。
4. 作業フォルダ：了承を得てから、`affinity_mcp_work/panels/` と `export/` がなければ作る。
5. 例の書き出し：`matlab -batch "run('<toolkit>/figure-types/make_all_examples.m')"`。`input/panels/` に 4 図の PNG・SVG・PDF・`_components.pdf`・JSON・`_data.mat` ができること。
6. 組み立て：`python tools/stack_component_pages.py panels` の後、`AFFINITY_COLLECT_DIR=<作業フォルダ>/install_check node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js`。ログの次の行を確かめる。
   - `[pages] pages=1`（空のページが残っていない）
   - `[check] text: Arial 7.50pt, Arial 9.00pt`（文字の大きさ。Mac では特に確かめる：README.md の 5.4 節）
   - `[figure area] page 90.00 x 60.00 mm …`（ページが段の幅）
   - `[export] … OK`、`[verify] exported PDF …`
7. `<作業フォルダ>/install_check/` に書き出した PNG を見て、元の図（`input/panels/<名前>.png`）と同じ配置であることを確かめる。
8. Panel style の登録：了承を得てから行う。`affinity/panel-tools/panel_style_loader.js` は変えずに、`toolPath` をこの環境の `<toolkit>/affinity/panel-tools/panel_style_tool.js`（絶対パス。区切りは `/`）に置き換えた写しを、`<作業フォルダ>/panel_style_loader_install.js` としてファイル作成用のツールで作る。`node tools/affinity-mcp.mjs save "Panel style" "<説明>" <作業フォルダ>/panel_style_loader_install.js` で登録し、写しを削除する。toolkit のファイルにパスを書き込まないのは、利用者のパス（ユーザー名を含む）が、toolkit を含むリポジトリの履歴に入らないようにするため。
   - 題名は「Panel style」。ユーザー向けの説明では「ローダー」という語を使わない。
   - 同じ題名があると登録できない（スクリプトパネルで削除してもらってから登録する）。
   - ダイアログの表示と操作は、ユーザーにスクリプトパネルから確かめてもらう（9）。
9. 人が確かめること：最後に、チャットで次の確認を頼む（AI はダイアログを操作できないため）。
   - Affinity で、6 で組み立てた例の図を表示する。
   - スクリプトパネル（メニューの ウィンドウ > スクリプト）の「Panel style」を実行し、ダイアログが開くことを確かめる。
   - 値を 1 つ変えて画面に反映されることを確かめ、キャンセルで閉じる。
   確かめたら「確認しました」「OK です」などと返すように伝える。うまくいかなければ、症状を伝えてもらい、README.md の 4 節（FAQ）に沿って原因を調べる。
10. 片付け：確認の返事があったら、導入の確認で作ったものを片付ける。Affinity で開いている例の 4 図（題名 kinematic_sequence、running_grf、jump_height、ball_speed_scatter）は、ユーザーに閉じてもらう（保存しない）。閉じたと返事があったら、了承を得て、`<作業フォルダ>/install_check/`、`<作業フォルダ>/input/panels/`、`<作業フォルダ>/panels/` の例の 4 図の .af を、一覧してから削除する。
11. チュートリアル（[examples/tutorial.md](examples/tutorial.md)）を始めるかを尋ね、始める場合はその手順で案内する。

## 4. 原案の作図スクリプトから図を作る手順

方針は [docs/figure-style.md](docs/figure-style.md) の「原案の作図スクリプトから図を作る」。ここでは手順とコマンドを書く。コマンドは figure-toolkit のフォルダで実行し、`<toolkit>`、`<原案のフォルダ>`、`<保存先>`（ユーザーが指定した成果物の保存先）、`<図の名前>` などは置き換える。`<保存先>` と `AFFINITY_COLLECT_DIR` は絶対パスで書く（コマンドは figure-toolkit のフォルダで実行するので、相対パスでは toolkit の中に置かれることがある）。

1. 依頼の確認：成果物の保存先の指定がなければ、作業の前に案を示して尋ねる（例：「図を作るフォルダを `<原案のフォルダ>/<図の名前>/` に作ってよいですか？」）。どの figure をどのパネルにするか、並べ方、図全体の幅が依頼文と原案から分からなければ、同じときに聞く。それ以外は聞かずに既定で作る。
2. 原案を読む（変更しない）：各 figure のデータの読み込み・計算、データを描くオブジェクト、軸ラベル、統計の結果を描く部分（text、ブラケットの plot など）を確かめ、figure-types の図の種類を決める。
3. 作図スクリプトを書く：`<保存先>/<図の名前>/make_<図の名前>.m`。構成は方針の 3、作図のしかたは figure-types の例と recipe.md に従う。
   - データの段落は原案と同じ読み込み・計算にし、見出しのコメントに原案の figure と行を書く。
   - 原案の統計の結果は、exportPanel の annotations に値を変えずに写す（ブラケット：x は原案の両端、y は原案の横線の高さ。文字：原案の文字）。
   - 書き出し先は `fullfile(toolkitPaths().input, '<図の名前>')` にする。
4. 実行：`matlab -batch "addpath('<toolkit>/matlab') ; run('<保存先>/<図の名前>/make_<図の名前>.m')"`
5. データの確認（パネルごと）：`matlab -batch "addpath('<toolkit>/matlab') ; run('<原案のスクリプト>') ; compareFigureData(figure(<番号>), fullfile(toolkitPaths().input, '<図の名前>', '<パネルの名前>_data.mat'), 'Panel <記号>')"`
   - `[summary] OK …`（データは一致）になることを確かめる。注釈に置き換えたブラケット・文字は `[--] 注釈に置き換え` と出る。
   - `[NG]` のときは、出力の「原案だけ」「論文用だけ」の一覧から原因を調べて直す。原案が figure の番号を使わないときは、原案の図のハンドルを渡す。
6. 組み立て（完成図の PDF・PNG は `<保存先>/<図の名前>/output/` に移す）。組み立ての前に、成分のページを 1 ページに並べる（`tools/stack_component_pages.py`。.af に空のページを残さないため）。
   - 接続の確認：組み立ての前に `node tools/affinity-mcp.mjs run affinity/compose/check_connection.js` で、Affinity への接続と作業フォルダの読み込みを確かめる。同じセッションの中ですでに確かめていれば（導入の確認、チュートリアルの 3、前の図の組み立てなど）、繰り返さない。接続できない、または `[NG] desktop` のときは、Affinity の起動と、設定 > モデルコンテキストプロトコル の「Affinity MCPを有効にする」「デスクトップ上のファイルへのアクセス」の確認を、ユーザーに頼む（README.md の 2.1 の 3。設定は AI が変えない）。
   - 単一パネル：`python tools/stack_component_pages.py <図の名前>` の後、`AFFINITY_COLLECT_DIR=<保存先>/<図の名前>/output node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js --set inputFolder=<図の名前>`
   - 複数パネル：例 `examples/draft_figures_2x2/` と同じ方式で行う（手順は make_draft_figures_2x2.m の冒頭）。並べ方の方針は未決定なので、パネルの大きさは次の暫定の規則による（2026-10-20）。
     - パネルの大きさ：作図スクリプト（3）で、全パネルの図の大きさと軸の枠の位置（innerPosition）を同じ値にする（例の `applyPanelLayout`）。幅は段の幅を列の数で割った値にする。2 列（double column）なら、例と同じ 95 × 65 mm、軸の枠 [1.6, 1.1, 7.4, 4.9] cm。3 列以上など、これに当てはまらないときは、軸の枠を含めて決め、自分で判断した点として報告する。
     - 配置の JSON：作図スクリプトの最後で、`<図の名前>_layout.json` を書き出し先（`input/<図の名前>/`）に書く。中身は `figureArea`（`column`、`widthMm`、`heightMm`）と、パネルごとの `panel`（パネル記号）、`source`（exportPanel の `spec.name`）、`offsetMm`（図の左上から、パネルの左上までの位置 [mm]）。例の make_draft_figures_2x2.m の「配置の JSON」の段落と同じ形にする。
     - まとめのスクリプト：`examples/draft_figures_2x2/combine_draft_figures_2x2.py` を `<保存先>/<図の名前>/combine_<図の名前>.py` に写し、`figure_name` を `<図の名前>` に書き換える（冒頭の説明の図の名前も合わせる。そのほかは変えない）。`input/<図の名前>/` のパネルを 1 つの PDF にまとめ、`input/test_figures/` に置く。
     - 実行：`python <保存先>/<図の名前>/combine_<図の名前>.py`、`python tools/stack_component_pages.py test_figures/<図の名前>.json` の後、`AFFINITY_COLLECT_DIR=<保存先>/<図の名前>/output node tools/affinity-mcp.mjs run affinity/compose/compose_test_figure.js --set testFigureName=<図の名前>` で組み立てる。
     - `tools/make_test_figure_4panels.py` は、Panel style の試験用の図を作るもので、原案から作る図には使わない（入力が `input/panels/` に固定されている）。
7. 組み立ての確認：`node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=<図の名前>`。`[summary] … NG 0 件` になることを確かめる。
8. 目視：完成図の PNG を見て、原案と同じ内容か、重なり・はみ出しがないかを確かめる。
9. 途中のファイルの削除：削除する前に対象を一覧し、この作業で作ったものだけであることを確かめてから削除する。
   - `affinity_mcp_work/input/<図の名前>/`（MATLAB の書き出し、`_data.mat`）
   - `affinity_mcp_work/input/test_figures/<図の名前>_components.pdf`、`<図の名前>_components_stacked.pdf`、`<図の名前>.json`（複数パネルのとき）
   - `affinity_mcp_work/check_<図の名前>.pdf`
   - 確認のためだけに作った一時的なスクリプト
   - .af と `<図の名前>/` の中のものは残す。
10. 報告：作ったファイル（作図スクリプト、完成図、.af）、確認の結果（データの一致、check_figure の NG の数、目視）、自分で判断した点、削除したファイル。1 回目の出力の報告では、Affinity で手を加える前に、図を成果物の保存先の `<図の名前>/` に別の名前（例：`<図の名前>_edited.af`）で保存するよう伝える（`affinity_mcp_work/panels/<図の名前>.af` は、図を作り直すと上書きされるため）。
11. 仕上げた図の書き出し：ユーザーが Affinity で仕上げた後に書き出しを頼まれたら、`affinity/compose/export_figure.js` で書き出す。
    - 例：`AFFINITY_COLLECT_DIR=<保存先>/<図の名前>/output node tools/affinity-mcp.mjs run affinity/compose/export_figure.js --set exportTitle=<題名> --set formats=pdf,png`
    - 推奨の設定（指定がなければこれで書き出す）：PDF は「書き出し用」（ベクターのまま、フォントを埋め込む）、PNG・TIFF は 600 dpi、色は RGB。「PDF で」「PNG で」のような短い依頼なら、その形式だけを推奨の設定で書き出す。形式の指定がなければ PDF と PNG。
    - ユーザーの指定（dpi、TIFF、CMYK、PDF/X-4 など）があれば従う（`--set dpi=1200`、`--set formats=tiff`、`--set cmyk=true`、`--set pdfx=true`）。
    - 対象の図（`exportTitle`）は、Affinity の文書の題名（拡張子なし）で指定する。ユーザーが別の名前で保存した図なら、その名前になる（例：`<図の名前>_edited`）。分からなければ尋ねる。題名が違うと `[NG] 対象の図が開いていない` と、開いている文書の一覧が出る。
    - 書き出し先は、その図の `output/`（同じセッションで作った図なら分かっている。分からなければ尋ねる）。名前は `<題名>_final…` で、組み立てのときの書き出しとは別になる。
    - 対象の図は、Affinity で今表示している状態（保存していない変更を含む）で書き出す。図を保存・変更・クローズしない（スクリプトもしない）。仕上げた図の保存はユーザーに頼む。
    - 書き出しの後、途中のファイル `affinity_mcp_work/export_source_<題名>.pdf` を削除し、書き出したファイルの場所・大きさ・dpi を報告する。
    - .af の保存の提案：書き出しの報告と一緒に、「仕上げた図（.af）も、書き出したファイルと同じ `<保存先>/<図の名前>/` に保存しましょうか」と提案する。ユーザーは「図を保存」の響きから、.af も保存先に保存されていると思っていることがあるため（デスクトップの作業フォルダの .af に気づいていないことがある）。
      - 書き出しのログの `[file]` の行で、対象の図の保存場所を確かめてから提案する。保存先の `<図の名前>/` の外（デスクトップの `affinity_mcp_work/panels/` の中、または保存されていない新規の図）なら、その場所の .af は組み立て直すと上書きされ、研究のフォルダには残らないことを短く伝える。
      - すでに保存先の `<図の名前>/` に保存されていて、未保存の変更がなければ、提案はせず、保存場所を報告に書く。未保存の変更だけがあれば、上書き保存（Ctrl+S）を勧める。
      - 了承されたら、保存の操作を案内する：Affinity の ファイル > 名前を付けて保存 で、場所は `<保存先>/<図の名前>/`、名前は `<図の名前>_edited.af` など（同じ名前の .af がそこにあれば、上書きしてよいか尋ねる）。保存はユーザーが行う（MCP のスクリプトはデスクトップの外に書けない。スクリプトの saveAs で保存場所を変えると、開いている図がデスクトップの写しを指すようになるため、使わない）。
      - 保存したと返事があったら、そのフォルダに .af があることを確かめて報告する。

チュートリアル：ユーザーに「figure-toolkit のチュートリアルを始めてください」（または「チュートリアルを始めてください」）と頼まれたら、[examples/tutorial.md](examples/tutorial.md) の手順で案内する。

試験用の入力（`examples/`）：
- `examples/draft_figures.m` は、手作業で書いた原案の作図スクリプトの例（体裁は MATLAB の既定、figure(1)〜(4)）。データと統計解析の結果は `examples/create_demo_data.m` が作る（figure-types の例と同じダミーデータ）。
- この手順や toolkit を変えたときは、`examples/draft_figures.m` を原案として手順を通し、結果を確かめる（例：「examples/draft_figures.m の figure 1〜4 を、2×2 のパネル（A〜D）に配置した図にしてください」）。
- `examples/draft_figures_2x2/` は、2026-10-19 に新しいセッションの AI がこの手順で作った例（作図スクリプト、複数パネルのまとめのスクリプト、完成図）。
- `examples/draft_figures.m` と `examples/create_demo_data.m` は、手順の試験の入力なので、試験の中では変更しない。

## 5. よく使う実行のしかた

| 作業 | コマンド（figure-toolkit のフォルダで） |
|---|---|
| 例をまとめて書き出す | `matlab -batch "run('figure-types/make_all_examples.m')"` |
| 1 つの図を書き出す | `matlab -batch "addpath('matlab') ; run('<図のスクリプト>')"` |
| 成分のページを 1 ページに並べる | `python tools/stack_component_pages.py <フォルダまたは JSON>`（作業フォルダの input/ からの相対でもよい。例：`panels`）。MATLAB で書き出し直すたびに、組み立ての前に実行する |
| 単一パネルの図を組み立てる | `AFFINITY_COLLECT_DIR=<移す先> node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js`。1 つの図だけにするときは `--set panelNames=<名前>`（複数はカンマ区切り）、入力を `input/<フォルダ名>` にするときは `--set inputFolder=<フォルダ名>` を付ける |
| 組み立てた図を確かめる | `node tools/affinity-mcp.mjs run affinity/compose/check_figure.js --set checkFigureTitles=<題名>`（複数はカンマ区切り。省略時は開いているすべての図） |
| 原案の図とデータを比べる | `matlab -batch "addpath('matlab') ; run('<原案のスクリプト>') ; compareFigureData(figure(<番号>), '<パネルの名前>_data.mat の場所', 'Panel <記号>')"` |
| 複数パネルの試験図 | `python tools/make_test_figure_4panels.py`、`python tools/stack_component_pages.py test_figures/test_figure_4panels.json` の後、`AFFINITY_COLLECT_DIR=<移す先> node tools/affinity-mcp.mjs run affinity/compose/compose_test_figure.js`（ほかの図は `--set testFigureName=<図の名前>`）。Panel style の試験用 |
| 仕上げた図を書き出す | `AFFINITY_COLLECT_DIR=<保存先>/<図の名前>/output node tools/affinity-mcp.mjs run affinity/compose/export_figure.js --set exportTitle=<題名> --set formats=pdf,png`（推奨の設定は 4 節の 11） |
| 接続を確かめる | `node tools/affinity-mcp.mjs run affinity/compose/check_connection.js`（Affinity への接続と、作業フォルダの読み込み） |
| 画面の画像を取る | `node tools/affinity-mcp.mjs render <見開きの番号> <出力.jpg> <sessionUuid>` |
| パレットを作り直す | `python palettes/make_ase_palettes.py`（Affinity への読み込みはユーザーが行う。SDK にパレットを読み込む API はない） |

- `AFFINITY_COLLECT_DIR`（書き出したファイルを移す先）は、絶対パスで指定する。指定しないと、書き出したファイルは作業フォルダの `export/` に残る（toolkit のフォルダには置かない）。
- Windows のシェル：
  - コマンドは bash の書き方（`変数=値 コマンド`）にしてある。PowerShell では `$env:AFFINITY_COLLECT_DIR = '<移す先>' ; node …` とする。
  - Git Bash では、MATLAB と Python の日本語の出力が文字化けすることがある（出力の文字コードが CP932 のため）。Python は環境変数 `PYTHONUTF8=1` を付けて実行する。MATLAB の `compareFigureData` の判定は、`[summary]` の行の `OK`・`NG` で読む。PowerShell では化けない。

MATLAB のコードをユーザーに渡すときは、推測ではなく `matlab -batch` で実行して確かめてから渡す。

## 6. Panel style の変更と確認

- 本体は `affinity/panel-tools/panel_style_tool.js`。項目の追加のしかたは本体の冒頭（「拡張のしかた」）。調整できる項目と実装の状況は docs/adjustable-properties.md に記録する。
- 登録した Panel style は、登録のときに入れた場所（3 節の 8）の本体を読む。本体を変えれば、登録し直さなくても次の実行から反映される。
- MCP での確認：次のような前置きのファイルを作り、本体の前に連結して `run` する。

  ```js
  globalThis.panelStyleTest = {
      documentTitle: 'test_figure_4panels',   // AI が開いたドキュメントの題名
      mode: 'preview',                        // 'preview'（プレビューして消す）または 'apply'（確定）
      sequence: [                             // 省略時は settings を 1 回だけ使う。ダイアログで欄を続けて変えたときの順を再現する
          { significance: { panels: { A: { text: '#', family: null, sizePt: null } } } },
          { significance: { panels: { A: { text: '#', family: null, sizePt: 12 } } } },
      ],
      onPreview: (doc, index) => { /* プレビュー中の状態を console.log で出す */ },
  } ;
  ```

  設定のキーは操作の `id`（`text`、`series`、`significance` など）で、中身は各操作の `readSettings` が返す形。
- 'apply' で確定した変更は、確認の後に AI が開いたドキュメントを閉じるか、組み立てをやり直して元に戻す。

## 7. Affinity の SDK で分かっていること（3.3.1）

- 見開き（ページ）を削除する API はない（見開きを選択に入れた削除のコマンドは対象 0 件、Node.delete も同じ処理。2026-10-19 に再確認）。そのため、成分のページは `tools/stack_component_pages.py` で 1 ページに並べてから開く（複数ページの PDF のまま組み立てると、2 ページ目以降が空のページとして残る）。pypdf で 1 ページに並べた PDF は、ページごとの要素の数・種類が元の PDF と同じに取り込まれ、元の位置へ戻したときの差は 0 だった。
- パレット・スウォッチを操作する API はない（.ase はユーザーが読み込む）。
- スクリプトパネルは同じ題名で登録し直せない。`userDescription`（レイヤー名）は現在の見開きのノードにしか設定できない（先に現在の見開きを切り替える）。
- `require(ファイルの場所)` は使える。`new Function`・`eval` は使えない。`localeCompare` は ICU のエラーになる。
- 文字の大きさの設定（`StoryDelta` の Height）は pt × dpi/72 で渡す。読み出しは属性値なので、実寸は `baseToSpreadTransform` の拡大率を掛ける。文字の大きさを変えると、文字の原点を中心に拡大縮小される。
- プレビュー（`executeCommand(command, true)`）は前のプレビューを置き換える。プレビュー中にノードの状態（文字、範囲、外形）を読むと、プレビュー後の状態が返る。変更のコマンドは、最初に読んだ元の状態から作る（2026-10-19、有意差記号の文字が一部残る不具合の原因）。
- 文字の範囲（`storyRange`）は末尾の段落の区切りを含み、文字数より 1 長い。文字を置き換えた後の範囲は、元の範囲の長さを文字数の差だけ変えて求める。
- 外形は base box（`getSpreadBaseBox`）を使う。visible box は文字の右側が約 0.7 mm 広い。
- 破線の「均等割り」（`balancedDashes`）は、短い線分の集まりである MATLAB の曲線では間隔が不揃いになるので使わない。
- 組み立ての既知の問題（2026-10-19 時点。未修正）：
  - Affinity の PDF の取り込みで 1 つの文字が 2 つに分かれることがある（例：縦軸のラベルが "V" と "ertical GRF (BW)"）。組み立てのスクリプトが 2 つを別々に揃え直すので、文字が 0.3〜0.4 mm 重なる。分かれ方は目盛り線の向きや数字の間隔で変わる。見つけたらユーザーに伝える（Affinity で手で直すか、組み立てのスクリプトの修正を待つ）。
  - 目盛り線を内向きにすると、Affinity では axes lines のサブレイヤーがデータより前面にあるので、目盛り線が棒の上に見える。
  - 組み立てのスクリプトを、MCP を通さずにスクリプトパネルから実行する方法は確かめていない。
- MATLAB の書き出しでは、文字の大きさが 0.75 pt の倍数（96 dpi の整数画素）に切り捨てられる（Windows で確認）。破線（`xline` の `'--'` など）は塗りの図形として取り込まれる。

## 8. 記録

- 作業の記録（ログ）とコミットは、置き場所のリポジトリの規約に従う。toolkit を .gitignore の対象の場所に置いている場合はコミットせず、ログにコミットメッセージ案を残す。`git add -f` は使わない。push はユーザーが行う。
- 試行の記録（SDK の調査、試行のスクリプト）は配布物に含まない。文書とコメントの「開発時の試行」の記号（A3、G7、I4 など）は、その記録の項目を指す。
