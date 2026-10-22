% 図の種類ごとの例（ダミーデータの単一パネルの図 4 種）を、まとめて書き出す
%
% 出力：デスクトップの affinity_mcp_work/input/panels/
%   <name>.png・.svg・.pdf（全体の図）、<name>_components.pdf（成分ごとのページ）、<name>.json（構成と注釈の指定）
% Affinity での組み立て（figure-toolkit のフォルダで）：python tools/stack_component_pages.py panels の後、
%   AFFINITY_COLLECT_DIR=<移す先の絶対パス> node tools/affinity-mcp.mjs run affinity/compose/compose_single_panels.js
% 実行：matlab -batch "run('<figure-toolkit>/figure-types/make_all_examples.m')"

% figure-toolkit/matlab をパスに加える（README の導入手順で保存していれば不要）
typesFolder = fileparts(mfilename('fullpath')) ;
addpath(fullfile(fileparts(typesFolder), 'matlab')) ;

run(fullfile(typesFolder, 'timeseries', 'example_kinematic_sequence.m')) ;
run(fullfile(typesFolder, 'timeseries', 'example_running_grf.m')) ;
run(fullfile(typesFolder, 'bar-points', 'example_jump_height.m')) ;
run(fullfile(typesFolder, 'scatter', 'example_ball_speed_scatter.m')) ;
