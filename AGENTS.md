# AGENTS.md

Codex 向けの入口。**正本は `CLAUDE.md`**（内容を二重管理しない）。本ファイルには Codex で読み替えが必要な差分だけを書く。

## セッション開始（`hi`）

1. `CLAUDE.md` を読み、その「セッション開始プロトコル」の手順どおりに進める（2〜8 の docs 群と backlog の OPEN 報告を含む）。
2. memory は Codex からは次の絶対パスで読む:
   `C:\Users\81809\.claude\projects\C--Users-81809-Documents-Repositories-setup-neovim-wezterm\memory\MEMORY.md`（ここから辿れるファイルも読む）
3. `CLAUDE.md` 内の「Claude Code」に関する運用ルール（編集ワークフロー・gotcha・回答スタイル・コミット規約）は Codex にもそのまま適用する。ただし下の差分表にある項目は Codex 側の記述を優先する。

## Codex での読み替え

| 項目 | Claude Code（CLAUDE.md の記述） | Codex での正本 |
|---|---|---|
| ステータス表示 | `claude/statusline.ps1` → `~/.claude/statusline.ps1` | `Codex/statusline.ps1`・`Codex/session-status.ps1`（WezTerm 下端の専用ペイン）。仕様 `Codex/statusline-spec.md`・`Codex/README.md` |
| ユーザー設定 | `~/.claude/settings.json` | `~/.codex/config.toml`（正本スニペット `Codex/runtime.toml`・`Codex/statusline.toml`）、フック `~/.codex/hooks.json` |
| Remote Control 自動接続 | `settings.json` の `remoteControlAtStartup: true` | **Codex に同等の設定キーは無い**。ログオンタスク `Codex Remote Control`（`Codex/remote-control.ps1`）が `ws://127.0.0.1:14567` に常駐し、`codex.exe` 隣の `codex.ps1` シム（`Codex/install-codex-shim.ps1`）が全 PowerShell 起動を `--remote` 経由にする。troubleshooting **#17・#22** |
| `Ctrl+Shift+N` | 新規ウィンドウで claude | 新規ウィンドウで Codex＋下端ステータス（`Codex/start-codex.ps1`） |
| 既知の地雷 | #12〜#16 | 加えて **#17〜#22・#26**（Remote Control の Windows 起動・409 競合・表示混線・context 値の差・スキル説明短縮・デスクトップ版の 409 再発で起動が止まる件） |

## Codex 固有の注意

- 「スマホから見えない」はまずプロセスの codex.exe コマンドラインに `--remote ws://127.0.0.1:14567` があるか確認。サーバー状態は RPC `remoteControl/status/read`（`Codex/remote-client.ps1`）の `connected` で判定し、`/readyz` の HTTP 200 を根拠にしない。
- デスクトップアプリ側の Remote Control は OFF のまま（同一登録で 409 競合）。
- Claude Code から `Codex/ask-codex.ps1` 経由でメッセージが届くことがある（スマホからの入力と同じ扱い）。**最後のメッセージだけが Claude に返る**ので、結論はターンの最後のメッセージにまとめる。
- Codex から Claude Code に頼む時は `pwsh -NoProfile -File .\Codex\ask-claude.ps1 '<依頼>'`（Claude の返答が標準出力に出る。長文は `-MessageFile`）。相手の Claude セッションが `claude-listen.ps1` で待受中の時だけ届く（このリポジトリの Claude は `hi` で自動的に待受を始める）。待受中のセッションが無いと exit 1 になるので、ユーザーに「Claude に Codex 待受を頼んで」と伝える。別リポジトリの Claude へは `-Name <セッション名>` か `-ClaudePid`。
- 検証用に WezTerm のウィンドウ・タブを増やさない。表示系の回帰確認は `python Codex/test-session-status.py`（GUI なし）を優先。
- コミット末尾の Co-Authored-By 行は、その時の実行環境の指定に従う（Anthropic のモデル名を流用しない）。
