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

`runtime.toml` は `approval_policy = "never"` と `sandbox_mode = "workspace-write"` を指定し、確認を挟まず実行する。書き込めるのはワークスペース（cwd）と `%TEMP%` 配下だけで、それ以外への書き込みは確認を求めずに失敗する（troubleshooting #27）。2026-09-14 に一度 `danger-full-access` にしたが、実際のユーザー設定は `workspace-write` に戻っていた。2026-09-15 に実際の設定を正とした。ブリッジで外から依頼が入るので、書き込み範囲の制限は残す。既存セッションの権限は変わらず、次回起動時に反映される。

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

`remote-client.ps1` の `Invoke-CodexRemoteRequest` はWebSocket RPCでRemote Controlの実際の状態を取得する。起動時はconnectedを確認し、サーバー未起動ならログオンタスクを開始する。共有サーバーが応答していてRemote Controlだけ未接続（`errored`＝多くはデスクトップ版との409競合）の場合は、警告を表示して共有サーバーへ接続したまま起動する（接続が戻ればその会話もスマホに出る）。共有サーバー自体が30秒応答しない場合だけ理由を表示して終了する。いずれもローカル専用起動へ黙って切り替えない（troubleshooting #26）。ネットワーク切断後の再接続はサーバー自身が行う。exec/review/doctor/管理コマンド・help/version・明示的な--remoteは元のCLIへそのまま渡す。resume/fork/agentsは共有バックエンドへ接続する。exeをフルパスで直接起動した場合はこの経路を通らない。

デスクトップ側のRemote ControlはOFFにする。同じ登録で複数サーバーを接続すると409 Remote app server already onlineになる。ローカル /readyz のHTTP 200だけをリモート接続完了と判断しない。

### Claude → Codex ブリッジ（2026-09-15）

`ask-codex.ps1` は、共有サーバー上のCodexの会話へメッセージを1通送り、Codexの最終返答を標準出力に返す。Claude CodeからCodexにレビューや作業を頼み、結果を受け取るための経路。スマホからの入力と同じ仕組みなので、CLIの画面にもそのまま出て、会話は分岐しない。

```powershell
pwsh -NoProfile -File .\Codex\ask-codex.ps1 'このdiffをレビューして'     # cwdで稼働中の最新のCodexへ
pwsh -NoProfile -File .\Codex\ask-codex.ps1 -MessageFile .\prompt.md  # 長文はファイルで渡す
pwsh -NoProfile -File .\Codex\ask-codex.ps1 -ThreadId <UUID> '...'    # 会話を指定する
pwsh -NoProfile -File .\Codex\ask-codex.ps1 -New -Cwd <dir> '...'     # CLIなしで新しい会話を作る
```

- 送り先の自動選択: 読み込み中（`thread/loaded/list`）の会話のうち、cwdが一致し、サブエージェントでないものが**ちょうど1つの時だけ**送る。2つ以上あれば、候補のIDと名前を出して送らずにexit 6（誤配送防止、backlog B14）。その時は `-ThreadId` で指定する。
- Codexが作業中（idle以外）なら、送らずに終了する。
- 途中経過（コマンド・編集・途中のメッセージ）は、標準エラーに `codex>` 付きで出す。
- 終了コード: 0 完了 / 1 失敗・送り先なし / 2 中断 / 3 タイムアウト（既定1800秒。ターン自体はCodex側で続く）。
- `-New` は会話の立ち上げに1分ほどかかる（実測72秒。既存の会話へは7秒）。作った会話はCodexの履歴に残る。承認要求に答えるCLIがいないので、`runtime.toml` の `approval_policy = "never"` が前提。
- 検証（2026-09-15）: 稼働中CLIの会話へ送り、「受信」を7秒で取得。送信後も会話は読み込み中・idleのままで、CLIも生存。Codexがいないcwdでは送らずにexit 1。`-New` でも返答の取得を確認。

### Codex → Claude ブリッジ（2026-09-15）

Claude Codeの対話セッションには、外から入力を差し込む公開APIが無い。セッション間通信（名前付きパイプ）は鍵で保護されていて、外から使うのは認証情報の扱いになるので採用しない。そこで、ファイルの受信箱と、Claude自身が起動する待受で実現する。

| 役割 | スクリプト | 動き |
|---|---|---|
| Codex | `ask-claude.ps1 '<依頼>'` | 待受中のClaudeの受信箱へ置き、返答ファイルを待って標準出力に出す |
| Claude | `claude-listen.ps1`（バックグラウンド） | 受信箱を0.7秒ごとに見る。1通届いたら内容とidを出して終了し、その終了通知でセッションが起きる |
| Claude | `claude-reply.ps1 -Id <id> -Message '<返答>'` | 返答を書く。Claudeはこの後、listenを再びバックグラウンドで起動する |

- 受信箱: `%LOCALAPPDATA%\Temp\codex-claude-bridge\<claude.exeのPID>\`（`inbox` → `processing` → `done`、返答は `outbox`）。CodexのWindowsサンドボックスは `%LOCALAPPDATA%` 直下に書けないので、Temp配下に置く（troubleshooting #27）。
- 書き込みは一時ファイルを書いてから名前を変える方式にし、書きかけのファイルを読まないようにしている。
- 待受の目印は `listener.json`。Claudeのプロセスは、listenの親プロセスをたどって `claude.exe` を見つけて特定する。PIDの再利用で別プロセスへ届かないよう、開始時刻も照合する。Claude Codeの自動更新は、動いている実行ファイルを `claude.exe.old.<数字>` に改名するので、その名前もClaudeとして扱う（troubleshooting #28）。
- 送り先の選び方: 既定はcwdが一致する待受中のセッションで、**ちょうど1つの時だけ**送る。2つ以上なら、候補を出して送らずにexit 6（backlog B14）。別リポジトリのClaudeへは `-Name <セッション名>` か `-ClaudePid`。待受中のセッションが無ければ、何も置かずにexit 1。
- 待受が次のメッセージを待つまでの間（返答中）に届いたものは、受信箱で待つ。タイムアウト（既定1800秒）までに受け取られなければ取り下げる。受け取り済みで処理中なら、そのままにする。
- 待受は時間制限の無いバックグラウンドのシェルで動く。Monitorツールは最長30分で止まるので使わない。
- 他リポジトリ向けの案内: 全リポジトリ共通の `~/.claude/CLAUDE.md`（Claude）と `~/.codex/AGENTS.md`（Codex）に、絶対パスでの使い方を書いた（2026-09-15、リポジトリ外のファイル）。他リポジトリのClaudeは、ユーザーに頼まれた時だけ待受にする。
- 待受の起動: このリポジトリのClaudeは、`hi` のセッション開始プロトコル（`CLAUDE.md` の手順9）で自動的に待受を始める。hiフック（`.claude/hooks/session-start-reminder.ps1`）の手順一覧には未反映（Claudeからのフック編集は自動モードでブロックされる）だが、フックは「差異があればCLAUDE.mdが勝つ」としている。`hi` 以外で始めたセッションでは、ユーザーが「Codex待受」と言った時に起動する。
- Claudeは、届いた依頼をユーザー本人ではなくCodexからの依頼として扱う。破壊的な操作は、通常どおりユーザーに確認する（`CLAUDE.md`）。
- 検証（2026-09-15）:
  - 疑似Codex（Claude側のシェル）から送り、31秒で往復。
  - 待受が無い時は、何も置かずにexit 1。
  - Codex本体の往復は、ClaudeがCodexに `ask-claude.ps1` の実行を頼む形で37秒。1回目は `%LOCALAPPDATA%` 直下でAccess deniedになり、Temp配下へ移して成功した。

### 自走ルールと上限（2026-09-15）

ユーザーが介入しなくても、ClaudeとCodexが複数往復の会話を続けて終えられるようにするための決まり。

| 決まり | 理由 |
|---|---|
| 会話を始めた側が進行役。続けて送る時は `-Conversation <id>` を付ける（idは最初の送信で標準エラーに出る） | 往復回数を会話ごとに数えるため |
| 返事を待たれている側は、明示的に頼まれた場合を除き送り返さない。聞きたいことは返答に書く | 投げ合いの暴走を防ぐ規律。固まること自体は、次の行（Claudeはバックグラウンドで待つ）と、Codexが作業中の送信の拒否（exit 5）で防いでいる |
| Claudeは `ask-codex.ps1` を必ずバックグラウンドで実行する | 前面だと、Codexからの依頼に返答できず固まる。Claudeの前面コマンドには10分の上限もある |
| 上限は1会話10往復、全体で30分20回。超えるとexit 4で送らない | 投げ合いの暴走を防ぐ。上限は `bridge-common.ps1` の定数 |
| 会話が終わったら、進行役が結論をユーザーに報告する | 結果が片方のセッションに埋もれないようにするため |

- 数える仕組み: `Register-BridgeTurn`（`bridge-common.ps1`）が、送信の直前に `conversations\<id>.json` の往復数と `asks.log` の直近の送信を、ロックファイルで排他して更新する。
- Codexへ届く文面の先頭には `[bridge conversation=<id> turn=<n>/10 from=claude]` と、送り返さない旨の注意書きが付く。Claudeの待受の出力にも、会話idと往復数が出る。
- 終了コード（両スクリプト共通）: 0 完了 / 1 失敗・送り先なし / 2 中断 / 3 タイムアウト / 4 上限で拒否 / 5 Codexが作業中（`ask-codex.ps1` のみ） / 6 送り先の候補が2つ以上で送らない。
- テスト用に、環境変数 `CODEX_CLAUDE_BRIDGE_ROOT` で受信箱と数える場所を差し替えられる。
- 検証（2026-09-15）:
  - 上限の単体テスト（テスト用の場所で実施）: 同じ会話の11回目と、全体で21回目の送信を拒否した。
  - 自走テスト（Claudeが進行役、会話 `b15a4f35` で3往復）:
    - 1往復目（62秒）: Codexがスクリプトを読み、弱点を3つ挙げた。
    - 2往復目（430秒）: 途中で、Codexが明示の許可を受けてClaudeへ問い合わせた（別の会話 `181e76e1` として1/10）。Claudeは約4分待ってから返答した。Claudeは `ask-codex.ps1` をバックグラウンドで待っていたので固まらなかった。Codex側の待機プロセスは5分以上生きていて、Codexは待つ間に受信箱を確認し続け、二重送信もしなかった。
    - 3往復目（17秒）: 結論に「同意」が返り、終了した。
  - テストで見つかった未決の2件（送り先があいまいな時に送らないか、許可した会話だけ受け付けるか）は、backlog B14・B15。
- 送信元の検証に使える情報（実測）: Codexのサンドボックス内から書かれたファイルの所有者は `CodexSandboxOnline`。待機中の `ask-claude.ps1` のpwshは、Claudeから所有者・コマンドライン・親（`codex-command-runner` → 共有サーバー）を読める。

検証: タスク再登録後Running、RPC connected、GUIを増やさないPTYでCLI起動→新規thread UUIDとモデル/effort/cwd/YOLO表示→切断時に同サーバーへのresume案内を確認。既存ステータスの回帰8件成功。共有サーバーのフックはTUIの環境変数を継承しないため、表示の紐付けはWezTermタイトルのthread UUIDとTUI PIDによる発見が担当する。
