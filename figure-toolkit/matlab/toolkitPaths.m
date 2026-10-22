function paths = toolkitPaths()
% 作図ツール一式（figure-toolkit）と作業フォルダの場所を返す（Windows・Mac 共通）
%
% 作業フォルダはデスクトップの affinity_mcp_work（MCP 経由の Affinity のスクリプトはデスクトップ配下しか読み書きできないため）。
% 出力：
%   paths.toolkit   figure-toolkit フォルダ（この関数のフォルダの 1 つ上）
%   paths.desktop   デスクトップ
%   paths.work      作業フォルダ（affinity_mcp_work）
%   paths.input     MATLAB の書き出し先（affinity_mcp_work/input）

% ホームフォルダ：Windows は USERPROFILE、Mac・Linux は HOME
if ispc
    homeFolder = getenv('USERPROFILE') ;
else
    homeFolder = getenv('HOME') ;
end
paths.toolkit = fileparts(fileparts(mfilename('fullpath'))) ;
paths.desktop = fullfile(homeFolder, 'Desktop') ;
% 環境変数 AFFINITY_WORK_DIR があれば、それを作業フォルダにする（tools/affinity-mcp.mjs と同じ変数）。
% Affinity が使うデスクトップ（app.userDesktopPath）がホームの Desktop と違う場合（Windows でデスクトップを OneDrive に移している場合など）に指定する
workOverride = getenv('AFFINITY_WORK_DIR') ;
if isempty(workOverride)
    paths.work = fullfile(paths.desktop, 'affinity_mcp_work') ;
else
    paths.work = workOverride ;
end
paths.input = fullfile(paths.work, 'input') ;
end
