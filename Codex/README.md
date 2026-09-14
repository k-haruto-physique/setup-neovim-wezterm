# Codex 4段ステータス表示

Codex 本体と同じ WezTerm ウィンドウの下端に、5セル高の専用ペインとして常時表示する。

表示順は次のとおり。

1. モデル名 + reasoning effort
2. コンテキスト使用率 + 5h/7d制限の使用率
3. 現在のディレクトリ
4. Git ブランチ

`Ctrl+Shift+N` で Codex 本体と4段ステータスを組にした新規ウィンドウを起動する。既に開いているCodexへは、そのペインを選んで `Ctrl+Shift+Y` を押すと下端へ後付けできる。

`wezterm start --always-new-process -- codex` で起動する場合も同じ構成になる。

Codex の内蔵ステータスは複数項目を指定しても横1行のため、`statusline.toml` の `status_line = []` で非表示にする。`statusline.ps1` が rollout JSONL を2秒間隔で読み、Claude版と同じモデル・effort・context・5h/7d制限・cwd・Git状態を4段で描画する。

レンダラーだけを単独確認する場合:

```powershell
pwsh -NoProfile -File C:/Users/81809/Documents/Repositories/setup-neovim-wezterm/Codex/statusline.ps1 -Watch
```

同じディレクトリで複数セッションを使う場合、`-SessionId <thread UUID>` で対象を固定できる。未指定時は、そのディレクトリの最近更新されたセッションを表示する。

`statusline.toml` の内容は `C:\Users\81809\.codex\config.toml` の `[tui]` へ反映する。既存のCodexセッションでは内蔵1行が残る場合があるため、新規セッションで完全に切り替わる。

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
