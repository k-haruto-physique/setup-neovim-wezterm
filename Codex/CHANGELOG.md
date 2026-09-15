# 変更履歴

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
