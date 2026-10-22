// Panel style のローダー（スクリプトパネル登録用。題名「Panel style」。2026-10-19）
//
// 本体（panel_style_tool.js）を toolPath から読み込んで実行する。
// 本体を更新したときは、toolPath の場所のファイルを置き換えるだけでよく、スクリプトパネルに登録し直す必要はない
// （スクリプトパネルは同じ題名で登録し直せないため）。
// 前提：Affinity の 設定 > スクリプト の「ファイルシステムへのアクセス」の一覧に、toolPath のあるフォルダが入っていること。
//
// 登録のしかた（AGENTS.md の 3 節の 8）：このファイルは変えずに、toolPath をこの環境の本体の場所（絶対パス。区切りは Windows・Mac とも /）に
// 置き換えた写しを作って登録し、写しは削除する。利用者のパス（ユーザー名を含む）が、toolkit を含むリポジトリの履歴に入らないようにするため。
//     Windows の例：'C:/Users/<ユーザー名>/Documents/<プロジェクト>/figure-toolkit/affinity/panel-tools/panel_style_tool.js'
//     Mac の例    ：'/Users/<ユーザー名>/Documents/<プロジェクト>/figure-toolkit/affinity/panel-tools/panel_style_tool.js'

// 仮の値。登録する写しで、この環境の場所に置き換える
const toolPath = '<toolkit>/affinity/panel-tools/panel_style_tool.js' ;

globalThis.panelStyleLoader = true ; // 本体が読み込まれた時点で実行しないようにする（実行は下の main で行う）
if (toolPath.startsWith('<toolkit>')) {
    alert('Panel style: 本体の場所（toolPath）が仮の値のまま登録されています。\n'
        + 'スクリプトパネルでこのスクリプトを削除し、AI に Panel style の登録を頼んでください（README.md の導入手順 2.2）。') ;
} else {
    try {
        require(toolPath).main() ;
    } catch (error) {
        alert(`Panel style: 本体を読み込めませんでした（${error.message}）。\n`
            + `設定 > スクリプト のファイルシステムへのアクセスに、次のフォルダが入っているか確認してください：\n${toolPath.replace(/\/[^/]*$/, '')}`) ;
    }
}
