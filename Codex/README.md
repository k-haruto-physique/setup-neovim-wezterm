# Codex TUI status line

WezTerm 内で起動する Codex のフッター設定。正本は `statusline.toml`。

表示順は次のとおり。

1. モデル名 + reasoning effort
2. コンテキスト残量
3. 現在のディレクトリ
4. Git ブランチ

Codex は Claude Code のような外部 status line スクリプトを呼ばず、`~/.codex/config.toml` の `[tui].status_line` を内蔵 TUI が描画する。したがって、Claude 版の4段表示・任意色・編集行数はそのまま移植できない。

`statusline.toml` の内容を `C:\Users\81809\.codex\config.toml` へマージし、新しい Codex セッションを起動すると反映される。`[tui.model_availability_nux]` が既にある場合は、その直前へ置く。

Claude 版と同じ4段表示を専用ペインで確認したい場合は、次を実行する。

```powershell
pwsh -NoProfile -File C:/Users/81809/Documents/Repositories/setup-neovim-wezterm/Codex/statusline.ps1 -Watch
```

この監視表示は Codex の rollout JSONL を読み、最後に記録された token count と rate limit を表示する。Codex 本体の入力欄へ埋め込むものではない。

## 自動承認と Remote Control

`runtime.toml` の設定により、承認が必要な操作は Codex の auto-review subagent が審査する。`approval_policy = "never"` は承認要求を自動却下する設定なので使用しない。

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
