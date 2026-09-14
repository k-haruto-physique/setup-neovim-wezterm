# Codex ステータス表示

Codex 本体と同じ WezTerm ウィンドウの下端に、4セル高の専用ペインとして常時表示する。

Codex内蔵フッターにモデル＋reasoning effort、コンテキスト残量、セッション名を表示する。名前は `/rename <名前>` で設定する。未命名なら名前の項目は省略される。

自作ペインは次の3行を表示する。

1. 5h/7d制限の使用率とリセットまでの時間
2. 現在のディレクトリ
3. Git ブランチ

通常の `codex`、`codex resume`、`Ctrl+Shift+N` のいずれでも、各Codexペインの下端へ表示を自動追加する。後から分割しても対象の直下へ自動で配置を直す。同じcwdでもプロセスID・ペインID・thread UUIDで区別する。新規タブやウィンドウを表示用に追加せず、操作中のタブを切り替えない。

セットアップ:

```powershell
pwsh -NoProfile -File .\Codex\install-session-status.ps1
```

このスクリプトは既存フックを保持して `~/.codex/hooks.json` のSessionStart/SessionEndを登録し、当該コマンド2個のハッシュだけを承認する。`[tui].terminal_title` と内蔵 `status_line = ["model-with-reasoning", "context-remaining", "thread-name"]` と `toggle_shortcuts = []` も設定する（`? for shortcuts` と `?` ヘルプを無効化、次回CLI起動時反映）。WezTermはタイトルから起動直後のセッションを捕捉し、最初のターンでSessionStartが完全なUUIDへ結び直す。再開時は同じ表示の対象を更新し、終了時は表示も終了する。`Ctrl+Shift+Y` は選択中の登録済みCodex表示を修復する。

モデル・effort・context・セッション名はCodexが表示する。自作側はcontextを計算しない。cwd・制限は対象セッションのrollout、Gitはそのcwdから取得する。5h/7d制限は最後に取得したスナップショットなので、同一アカウントでも更新時刻に差がある。UUIDが曖昧、ログ未生成、制限未取得の場合は `limits: unavailable` と表示する。

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


### CLI中心の自動Remote Control（2026-09-14）

PowerShellの `codex` は `codex.exe` と同じフォルダに置いた `codex.ps1`（`codex-shim.ps1` の複製）に解決され、`start-codex.ps1` が `--remote ws://127.0.0.1:14567` と現在のcwdを渡す。PowerShellは同一フォルダでは.ps1を.exeより優先するため、**プロファイル未読込の既存シェルやNoProfileでも効く**（Claude Codeの `remoteControlAtStartup` 相当の起動経路非依存）。Ctrl+Shift+Nも同じスクリプトを呼ぶ。配置は `pwsh -NoProfile -File .\Codex\install-codex-shim.ps1`、Codex更新でbinが置き換わっても `remote-control.ps1` がログオン時に再配置する。パイプ入力付きの呼び出しは素のexeへ渡す。対象外はcmd.exe・exeのフルパス直接起動・デスクトップアプリ。既存のローカルCLI会話は自動では移らず、終了後に `codex resume --last` で共有バックエンドへ再開する。

`remote-client.ps1` の `Invoke-CodexRemoteRequest` はWebSocket RPCでRemote Controlの実際の状態を取得する。起動時はconnectedを確認し、サーバー未起動ならログオンタスクを開始する。30秒以内に接続できない場合は理由を表示して終了し、ローカル専用起動へ黙って切り替えない。ネットワーク切断後の再接続はサーバー自身が行う。exec/review/doctor/管理コマンド・help/version・明示的な--remoteは元のCLIへそのまま渡す。resume/fork/agentsは共有バックエンドへ接続する。exeをフルパスで直接起動した場合はこの経路を通らない。

デスクトップ側のRemote ControlはOFFにする。同じ登録で複数サーバーを接続すると409 Remote app server already onlineになる。ローカル /readyz のHTTP 200だけをリモート接続完了と判断しない。

検証: タスク再登録後Running、RPC connected、GUIを増やさないPTYでCLI起動→新規thread UUIDとモデル/effort/cwd/YOLO表示→切断時に同サーバーへのresume案内を確認。既存ステータスの回帰8件成功。共有サーバーのフックはTUIの環境変数を継承しないため、表示の紐付けはWezTermタイトルのthread UUIDとTUI PIDによる発見が担当する。
