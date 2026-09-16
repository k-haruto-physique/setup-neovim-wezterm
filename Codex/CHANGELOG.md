# 変更履歴

## 2026-09-16 — ステータスをタブバーへ移設（ペイン分割を廃止）

- きっかけはユーザー指摘「ペイン分割した時によめなくね?」。実測で、Codex 内蔵 status line は**3 項目で既に 63 桁**、制限まで載せると約 86 桁。当時のクロコ側ペインは **47 桁**で、ペイン内表示は分割前提の運用と構造的に噛み合わないと確定した。
- 置き場所は値の性質で決める（ユーザー指摘で初版から修正）。**セッション固有**（モデル+effort / context / cwd / branch）は Codex 内蔵 status line、**アカウント共通**の 5h/7d 使用制限だけをタブバーへ。タブバーはウィンドウに 1 本しかないので、ペインごとに違う cwd を出すとどのセッションのものか分からなくなる。
- `tabbar-status.ps1` を新設。**1 プロセス**で全 Codex ペインを見て、ペインタイトルの thread UUID から rollout を解決し、**最も新しい** rollout の使用制限を `%LOCALAPPDATA%\Temp\codex-status\account.json` に 1 つだけ書く。`wezterm.lua` は Codex ペインがアクティブな時だけこれを `set_right_status` する。タブバーは**ウィンドウ幅（190 桁）なので分割に不感**。
- 内蔵は `status_line = ["model-with-reasoning", "context-remaining", "project-name", "git-branch"]`。`terminal_title` は監視の結合キー（`session-id`）なので変更しない。
- ライフサイクルフック（`hooks.json` → `session-status.ps1`）と、ペインの分割・移動・幾何修復（#19）は**すべて不要**になった。`Ctrl+Shift+Y` も廃止。旧ファイル群の物理削除は実機確認後（backlog B17）。
- 🚫 `wezterm.lua` から監視プロセスを起動してはいけない。`wezterm.background_child_process` で `conhost --headless pwsh` を起こしたところ、**30 秒ごとに 0xc0000142 のモーダルダイアログ**が出た（System ログ ID 26 で 6 件・conhost の Application Error 10 件を確認）。wezterm-gui はコンソールを持たない GUI プロセスなので子の conhost が初期化できない。起動はログオンタスク `Codex Tab Bar Status`（`register-tabbar-status-task.ps1`）の責務にし、Lua は読むだけにした。詳細 troubleshooting #29。

## 2026-09-15 — 送り先があいまいなら送らない（backlog B14）

- `bridge-common.ps1` に `Select-BridgeTarget` を追加。`ask-codex.ps1`・`ask-claude.ps1` は、送り先の候補が2つ以上あると送らずにexit 6にする（以前は最新を自動で選び、警告だけ出して送っていた）。
- 相手の指定は、Codex宛てが `-ThreadId`、Claude宛てが `-ClaudePid`（名前が一意なら `-Name`）。
- 結合テストで、自動更新前から開いているClaudeセッション（プロセス名が `claude.exe.old.<数字>`）を認識できないバグを発見し修正（troubleshooting #28）。修正後、改名済みの実在セッション2つで、あいまいならexit 6・`-ClaudePid` 指定なら配送、を確認。
- B15（許可した会話だけ受け付ける方式）は導入しない。ブリッジ経由の破壊的・外部送信の操作は、Claudeがユーザーに確認する運用を続ける。

## 2026-09-15 — 自走ルールと上限

- `bridge-common.ps1` に往復数の上限を追加（1会話10往復、全体で30分20回。超えたらexit 4）。`-Conversation <id>` で会話を続ける。Codexが作業中なら、`ask-codex.ps1` はexit 5。
- 自走ルール（Claudeはバックグラウンドで待つ、明示的に頼まれない限り送り返さない、進行役が結論を報告する）を、repoのdocsと全リポジトリ共通の2ファイルに記載。
- ClaudeとCodexで3往復の自走テスト（62秒・430秒・17秒）。入れ子の問い合わせと約4分の返答待ちでも固まらず、二重送信も無かった。未決の2件は backlog B14・B15。

## 2026-09-15 — 権限設定を実際の設定に合わせる・待受の自動起動

- `runtime.toml` を `sandbox_mode = "workspace-write"` に変更。実際のユーザー設定を正とした（troubleshooting #27）。
- Claude 側の待受（`claude-listen.ps1`）を、このリポジトリの `hi` で自動起動する運用にした。
- 全リポジトリ共通の `~/.claude/CLAUDE.md`・`~/.codex/AGENTS.md` に、ブリッジの使い方を追加（他リポジトリの Claude は頼まれた時だけ待受）。

## 2026-09-15 — Codex → Claude ブリッジ

- `ask-claude.ps1`（Codex側）、`claude-listen.ps1`・`claude-reply.ps1`（Claude側）、`bridge-common.ps1` を追加。ファイルの受信箱で、待受中のClaudeへ依頼し、返答を受け取る。
- 受信箱は `%LOCALAPPDATA%\Temp\codex-claude-bridge`。直下の `%LOCALAPPDATA%` は、Codexのサンドボックスで書けなかった（troubleshooting #27）。
- 疑似Codexとの往復31秒、待受が無い時に置かないこと、Codex本体の往復37秒を確認。

## 2026-09-15 — Claude → Codex ブリッジ

- `ask-codex.ps1` を追加。共有サーバー上の稼働中の会話（または `-New` で作る会話）へ1通送り、最終返答を標準出力に返す。
- 送り先はcwdで自動選択。作業中なら送らない。途中経過は標準エラー。終了コードは0/1/2/3。
- 稼働中CLIとの往復7秒、送信後もCLIの会話がidleのままであること、送り先が無い時に送らないこと、`-New` での往復を確認。

## 2026-09-14 — 内蔵表示への移行

- モデル＋effort・context残量・セッション名を内蔵フッターへ移行。`/rename` で命名。
- 自作側のcontext計算結果の表示を廃止。制限/cwd/Gitの3行・4セルへ縮小。

## 2026-09-14

- 再開後に別タブへ残った旧セッション固定の表示を、現在のCodex下端へ作り直して復旧。タブ閉じるボタンと、タブ/ペインの明示終了キーを追加。

- 内蔵status_lineの4項目指定は横1行だったため非表示化。
- 別ウィンドウの監視表示を同一ウィンドウ下端の5セル高・4段表示へ変更。
- Ctrl+Shift+NでCodexと同時起動、Ctrl+Shift+Yで既存ペインへ追加。
- Claude版に合わせた色、effort、context容量、制限リセット時間、Git状態を表示。
- SessionIdによる対象固定とログ末尾の効率的な読み取りを追加。
- 稼働中のWezTermで4行と現在の使用率を確認。
- 定期的な全画面消去をやめ、変更行のみの一括描画で点滅を解消。
- 自動承認をAI審査方式から、never + danger-full-accessの確認なし実行へ変更。


## 2026-09-14 — セッション別の自動表示

- cwd推測からPID・owner pane・thread UUIDの結合へ変更。タイトル捕捉とSessionStart/Endで通常起動・再開・終了へ追従。
- 同cwdの並列モデルを区別し、モデル/effortの即時変更と対象cwdのGitを表示。累積contextへの代替を廃止。
- 5セル表示とフォーカス維持。終了済み表示の残留を防ぎ、修復キーは登録済みセッションだけを対象にする。
- フック2個だけのハッシュ承認を再現できるinstaller、GUIを開かない8件の回帰確認、Excelスキルのアイコン警告修復スクリプトを追加。


### 同日 — 分割位置の追従

- ownerの直下/幅/高さ5セルを監視し、崩れた表示だけを移動。ズーム時は維持しフォーカスを復元。
- 表示ペインでの既定分割キーをownerへ転送。ユーザーのシェルを保持。
- composer.toggle_shortcuts=[]を設定し、次回起動からshortcuts案内と `?` overlayを無効化。
- 配置の回帰を追加、GUIなし9件成功。


## 2026-09-14 CLI Remote Control起動の統一

- start-codex.ps1とremote-client.ps1を追加。対話CLIは共通Remote Controlサーバーへ接続し、実接続状態を確認する。
- PowerShell codex関数とCtrl+Shift+Nを同経路に統一。ログオンタスクにStartWhenAvailableを追加。
- デスクトップとの409競合を特定し、ユーザーのCLI中心方針で解消。PTY起動と回帰8件を検証。
