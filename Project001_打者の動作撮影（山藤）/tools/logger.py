import os
import datetime

# シンプルな追記ロガー
# 使い方: from tools.logger import log
#       log("メッセージ")

def _default_log_path():
    # プロジェクト内の logs フォルダに保存
    base = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(base, '..'))
    logs_dir = os.path.join(project_root, 'logs')
    os.makedirs(logs_dir, exist_ok=True)
    return os.path.join(logs_dir, 'agent_log.md')


def log(message, filepath=None):
    """メッセージをタイムスタンプ付きでログファイルに追記します。

    Parameters:
        message (str): ログに書き込むメッセージ（改行禁止推奨）。
        filepath (str|None): 保存先ファイルパス。未指定ならプロジェクト内 logs/agent_log.md。

    Returns:
        str: 実際に書き込んだファイルパス
    """
    if filepath is None:
        filepath = _default_log_path()
    ts = datetime.datetime.now().isoformat(sep=' ', timespec='seconds')
    line = f"- {ts}  {message}\n"
    with open(filepath, 'a', encoding='utf-8') as f:
        f.write(line)
    return filepath
