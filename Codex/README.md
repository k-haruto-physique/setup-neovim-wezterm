# Codex 4段ステータス表示

Codex 本体と同じ WezTerm ウィンドウの下端に、5セル高の専用ペインとして常時表示する。

表示順は次のとおり。

1. モデル名 + reasoning effort
2. コンテキスト使用率 + 5h/7d制限の使用率
3. 現在のディレクトリ
4. Git ブランチ

通常の `codex`、`codex resume`、`Ctrl+Shift+N` のいずれでも、各Codexペインの下端へ表示を自動追加する。同じcwdでもプロセスID・ペインID・thread UUIDで区別する。新規タブやウィンドウを表示用に追加せず、操作中のタブを切り替えない。

セットアップ:

```powershell
pwsh -NoProfile -File .\Codex\install-session-status.ps1
```

このスクリプトは既存フックを保持して `~/.codex/hooks.json` のSessionStart/SessionEndを登録し、当該コマンド2個のハッシュだけを承認する。`[tui].terminal_title` と内蔵 `status_line = []` も設定する。WezTermはタイトルから起動直後のセッションを捕捉し、最初のターンでSessionStartが完全なUUIDへ結び直す。再開時は同じ表示の対象を更新し、終了時は表示も終了する。`Ctrl+Shift+Y` は選択中の登録済みCodex表示を修復する。

モデルとeffortは現在の端末タイトルを優先し、context・cwd・Gitは対象セッションのrolloutから取得する。5h/7d制限は各セッションで最後に取得した値なので、同一アカウントでも更新時刻に差がある。UUIDが曖昧、ログ未生成、使用量未取得の場合はcontextを `unavailable` と表示する。

表示単独の診断には `statusline.ps1 -SessionId <thread UUID>` を使う。SessionIdなしの単発診断だけはcwdの最新ログを選ぶ。自動表示はこの推測経路を使わない。

GUIを開かない回帰確認:

```powershell
python .\Codex\test-session-status.py
```

Excelスキルのアイコン警告を再修復する場合は `pwsh -NoProfile -File .\Codex\repair-skill-icons.ps1`。プラグインキャッシュ更新後に再発した場合にも使える。

## 自動承認と Remote Control

`runtime.toml` は `approval_policy = "never"` と `sandbox_mode = "danger-full-access"` を指定し、確認を挟まず実行する。ユーザー設定 `~/.codex/config.toml` にも反映済み。`never` だけではサンドボックス外の操作が失敗するため、両方を組にする。既存セッションの権限は変わらず、次回起動時に反映される。

Remote Control は `config.toml` に自動起動キーがないため、Windows のタスク `Codex Remote Control` がログオン時に `remote-control.ps1` を非表示で起動する。

```powershell
pwsh -NoProfile -File .\Codex\register-remote-control-task.ps1
```

登録後は `remote-control.ps1` がループバック限定の app-server を foreground で常駐させる。現行 Windows 版では `remote-control` の一時ソケットACL検証と `remote-control start` の daemon 分離がタスク起動と両立しないため、内部の実体コマンド `codex app-server --remote-control --listen ws://127.0.0.1:14567` を使用する。

稼働確認:

```powershell
Get-ScheduledTask -TaskName 'Codex Remote Control'
Invoke-WebRequest http://127.0.0.1:14567/readyz
Get-Content ~/.codex/logs/remote-control.log -Tail 30
```

公式仕様:

- <https://developers.openai.com/codex/config-file/config-reference>
- <https://learn.chatgpt.com/codex/config-file/config-sample>
