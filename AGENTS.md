# AI エージェント共通入口（mshinyalab_baseball_projects）

このリポジトリでは Codex、Claude Code など複数の AI エージェントを使う。このファイルには、リポジトリ全体に関わる決まりだけを書く。

- 各研究プロジェクト（`Project*_*/`）での作業は、作業対象のプロジェクトの AGENT.md・AGENTS.md・Claude.md・Codex.md と userinfo.md に従う。
- リポジトリ全体に関わる作業（このファイル、`figure-toolkit/` など）のログは `logs/` に、`logs/YYYY-MM-DD_NN.md` の名前で置く。各プロジェクトの作業のログは、そのプロジェクトの決まりの場所に置く。

## figure-toolkit（論文用の図を作るツール）

`figure-toolkit/` は、MATLAB で描いた図の原案を、AI と Affinity で論文用の図にするツール一式。人向けの説明は [figure-toolkit/README.md](figure-toolkit/README.md)、AI 向けの手順は [figure-toolkit/AGENTS.md](figure-toolkit/AGENTS.md)。元は教員（進矢）の optimal-motor-control-collaboration リポジトリの `sandbox-shinya/figure-toolkit/` で、更新はそちらで行い、このリポジトリへ写す。

### ユーザーロールが student のときの例外

各プロジェクトの AGENT.md・AGENTS.md・Claude.md・Codex.md には、「ユーザーロール（userinfo.md の role）が student の場合、AI はコードの修正案を提示するだけにして、ファイルの更新を行わない」という決まりがある。figure-toolkit を使う作業では、次のものに限り、この決まりの例外とする。ロールが student のときも、AI がファイルを作成・更新し、実行してよい。この例外は、各プロジェクトの決まりより優先する。

- figure-toolkit/AGENTS.md の手順で AI が書く作図スクリプト（`make_<図の名前>.m`）と、複数のパネルをまとめるスクリプト（`combine_<図の名前>.py`）
- Affinity のスクリプトの実行（`figure-toolkit/affinity/` のスクリプトを MCP 経由で実行する、図の組み立て・確認・書き出しと、Panel style の登録）
- figure-toolkit の導入の作業（必要なソフトウェアの確認、MATLAB の startup.m に toolkit のパスを加える 1 行など。figure-toolkit/AGENTS.md の 3 節のとおり、了承を得てから行う）

例外に含まないもの（ロールが student のときは、これまでどおり修正案の提示と説明にとどめる）：

- 原案の作図スクリプト（データの読み込み、計算、データを描く部分）と、分析のコード。figure-toolkit の方針でも、原案とデータは人が書き、AI は変更しない。
- figure-toolkit 自体のファイル。このリポジトリでは変更しない。不具合や改善の案は、ログにまとめて教員に伝える。

AI は、ロールが student のユーザーに作図スクリプトを渡すとき、各段落（データ、データを描く、体裁、注釈、書き出し）が何をしているかを説明し、データの段落を原案と見比べて確かめるよう伝える。
