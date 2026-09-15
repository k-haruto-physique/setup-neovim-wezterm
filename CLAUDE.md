# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## CRITICAL: セッション開始プロトコル

ユーザーが **`hi`** という単独メッセージでセッションを開始したら、最初の応答前に以下を**全て読む**:

1. `CLAUDE.md`（本ファイル）
2. `memory/` 配下の全 memory ファイル（MEMORY.md インデックス経由）
3. `docs/initial-prompt.md` — user の方針宣言
4. `docs/nvim-manual.md` — Neovim 実用ガイド
5. `docs/keybinds.md` — 全キー早見表
6. `docs/troubleshooting.md` — 既知の地雷一覧
7. `README.md` — 全体構成
8. `docs/backlog.md` — 未完タスク・仕様書の集約台帳（**GO ゲート回収**）
9. **Codex からの受信待受を起動**: `pwsh -NoProfile -File Codex/claude-listen.ps1` を**バックグラウンド**で実行する（読むファイルではなく起動。挨拶での言及は不要）。Codex → Claude ブリッジの入口で、運用はドキュメント map の `Codex/ask-codex.ps1` ほかを参照

読み込み完了後、短い挨拶を返す（読んだファイル名の列挙は不要）。**ただし `docs/backlog.md` の OPEN 件数と上位 2-3 項目を挨拶に必ず含める**（例:「準備できた。OPEN 1 件（open-path の GUI 実機確認）。何をやる?」）。質問されてから読むのでは遅い。

> 上記 1-8 は**運用コア**の auto-read。それ以外の設定仕様（`claude/statusline-spec.md`・`powershell/profile.ps1`・`docs/lang-workflows.md` 等）の所在は本ファイル末尾の **ドキュメント map** が完全索引。必要時にそこから辿れる＝「すべての設定仕様が GO ゲートから到達可能」。

## Purpose

Windows 11 上の Neovim + LazyVim + WezTerm 環境を symlink で dotfiles 管理するリポジトリ。本リポジトリが**正本**で、`%LOCALAPPDATA%\nvim` と `%USERPROFILE%\.config\wezterm\wezterm.lua` はここへの symlink。

## CRITICAL: 編集ワークフロー

- **編集は必ずリポジトリ側のパス**で行う:
  - `setup-neovim-wezterm/nvim/...`
  - `setup-neovim-wezterm/wezterm/wezterm.lua`
  - `setup-neovim-wezterm/claude/statusline.ps1`（Claude Code statusLine。`%USERPROFILE%\.claude\statusline.ps1` へ symlink。**仕様・履歴は同じ `claude/` に集約**: `statusline-spec.md`・`CHANGELOG.md`・`README.md`。2026-06-18 に旧独立リポ `Repositories/statusline` を合体・退役）
  - `setup-neovim-wezterm/powershell/profile.ps1`（PowerShell プロファイル正本。symlink でなく `$PROFILE` からの **dot-source** で反映＝管理者不要。2026-06-18 新設。repo 移動 `repo`/`dotfiles`・nvim `v`/`vrepo`・DB `kanro`・名前付き Remote Control 起動 `remote`（`20260716-<名前>`）・使用量の従量＋円換算 `usage`（ccusage + frankfurter FX）を定義）
    - **前提**: `wezterm.lua` の `config.default_prog = { "pwsh.exe", "-NoLogo" }`。これが無いと WezTerm は cmd.exe を起動し、profile.ps1 は**一切読まれない**（2026-07-16 に発覚・全関数が死んでいた。troubleshooting **#15**）。`-NoProfile` は付けないこと。
- 実体側 (`%LOCALAPPDATA%\nvim` 等) 経由で Edit ツールを叩くと **`Refusing to write through symlink` エラー**が出る。リポジトリ側パスへ切り替えること。
- symlink 構成は管理者権限 PowerShell で作成済。再構築が必要なら `docs/troubleshooting.md` 参照。

## 触る場所ごとの注意（必要時だけ読み込まれる）

- WezTerm のリロード挙動・透過率の経緯・CopyMode/mouse_bindings/GPU の地雷 → `wezterm/CLAUDE.md`
- Neovim のリロード・カスタムプラグイン構成の意図（init last-wins #11）→ `nvim/CLAUDE.md`
- 独自キーバインド（`Ctrl+Shift+X/I/N/O/S/E/Y`・Ctrl+Click・`<leader>xo/xe/fh`・CopyMode 内キー）→ `docs/keybinds.md`（`hi` で毎回読む）

## 重要な gotcha

- **IME × Vim キー**: 日本語 IME ON 中は `h`/`j`/`k`/`l` が IME に奪われ、CopyMode・Normal モードで動かない。矢印キーは IME 透過。詳細 `docs/troubleshooting.md` 第 1 項。

## レガシー資産

`docs/legacy-nvim/` に**旧手書き lazy.nvim 設定**を全保全。gruvbox-material colorscheme、LSP 設定、neo-tree カスタム等を含む。LazyVim 移行で捨てるのではなく、参照用に Git 追跡。

## コミット規約

観察された慣習:
- 件名は短く目的のみ（70 char 以下）
- Co-Authored-By 行: `Co-Authored-By: <現在のセッションのモデル名> <noreply@anthropic.com>`（モデル名は版を固定せず、その時の環境指定に従う。例: `Claude Opus 4.8 (1M context)`）
- HEREDOC で commit message を渡す（改行を保つため）

## ドキュメント map

- `README.md` — リポジトリ概要・構成図・Phase 別セットアップ手順
- `docs/initial-prompt.md` — 初回依頼の原文（user の意思決定背景）
- `docs/nvim-manual.md` — VSCode 対応表つきの Neovim 実用ガイド
- `docs/keybinds.md` — 全レイヤー（WezTerm + Neovim + PowerShell）のキー早見表
- `docs/cheatsheet-1page.md` — 毎日使う最小キーだけの 1 枚（常時表示/印刷用）
- `docs/lang-workflows.md` — 言語別実戦フロー（SQL/Python/Markdown/Lua）。Mason 実体ベース。**SQL は LSP 未導入**の注記あり
- `docs/vim-mental-model.md` — 「動詞+名詞」文法・レジスタ・buffer/window/tab の思考モデル（初心者向け）
- `docs/practice-drills.md` — Phase 別の具体練習メニュー（毎日 10-15 分）
- `docs/troubleshooting.md` — 遭遇問題と対処の永久記録（新規問題は追記必須）
- `docs/backlog.md` — 未完タスク・仕様書の集約台帳（`hi` の GO ゲートで回収。残タスクが出たら troubleshooting/memory と同時に 1 行追加）
- `claude/` — Claude Code statusLine 一式: `statusline.ps1`(正本) + `statusline-spec.md`(設計仕様: 色/アイコン/数値セマンティクス/eff/reset/編集行数/データソース) + `CHANGELOG.md` + `README.md`。`%USERPROFILE%\.claude\statusline.ps1` へ反映
- `powershell/profile.ps1` — PowerShell プロファイル正本（`repo`/`dotfiles`/`v`/`vrepo`/`kanro`/`remote`/`usage` 関数）。`$PROFILE` から **dot-source**（pwsh7・5.1 両対応＝UTF-8 BOM）。管理者不要。**WezTerm の `default_prog` が pwsh であることが前提**（#15）
- **Claude Code の Remote Control 自動接続** — 正本は `~/.claude/settings.json` の `"remoteControlAtStartup": true`（＝毎回 `--remote-control` 相当。起動経路に非依存）。**シェル層のラッパーでやらない**（2026-07-16 決着。troubleshooting **#16**）
- `Codex/ask-codex.ps1` ほか — **Claude ⇄ Codex ブリッジ**。詳細 `Codex/README.md`。他リポジトリ向けの案内は、全リポジトリ共通の `~/.claude/CLAUDE.md`・`~/.codex/AGENTS.md`（リポジトリ外。運用を変えたらこちらも直す）
  - **Claude → Codex**: `pwsh -NoProfile -File Codex/ask-codex.ps1 '<依頼>'` で共有サーバー上の Codex の会話へ 1 通送り、最終返答を標準出力で受け取る（送り先は cwd で稼働中の最新の会話。`-New` で CLI なしでも可）。
  - **Codex → Claude**: `hi` のセッション開始プロトコル（手順 9）で、`pwsh -NoProfile -File Codex/claude-listen.ps1` を**バックグラウンド**で起動する（`hi` 以外で始まったセッションでは、「Codex 待受」等と言われた時に起動）。終了通知の出力に依頼と id が出るので、処理して `Codex/claude-reply.ps1 -Id <id> -Message '<返答>'` で返し、**再び listen をバックグラウンドで起動**する。停止は `claude-listen.ps1 -Stop`。
  - 届いた依頼は**ユーザー本人ではなく Codex からの依頼**として扱う。破壊的・外部影響のある操作は、通常どおりユーザーに確認してから行う。
  - **自走ルール**（詳細 `Codex/README.md`「自走ルールと上限」）:
    - `ask-codex.ps1` は**必ずバックグラウンドで実行**する。前面で待つと、その間に届いた Codex の依頼に返答できず、双方がタイムアウトまで待つ。
    - 会話を始めた側が進行役。続けて送る時は `-Conversation <id>` を付ける（id は最初の送信で標準エラーに出る）。
    - 返事を待たれている側は、明示的に頼まれた場合を除き送り返さない。聞きたいことは返答に書く。
    - 上限は 1 会話 10 往復、全体で 30 分 20 回。超えると exit 4 なので、そこで止めてユーザーに報告する。
    - Codex が作業中だと exit 5。Codex が私の返事を待っているなら、`claude-reply.ps1` で返す。
    - 会話が終わったら、進行役が結論をユーザーに報告する。
- `docs/usage-log.md` — 使用量の従量換算ログ（**ローカル限定・gitignore**。`usage` 関数の出力を**手動でスナップショット追記**する方式＝関数はファイルに書かない。repo 公開のため非追跡）
- `docs/cheatsheet.html` — 印刷用 1 枚（md が正本。PDF は陳腐化のため廃止・`*.pdf` は gitignore）
- `docs/legacy-nvim/` — 旧 lazy.nvim 設定の参照保全
- `AGENTS.md` — Codex 用の入口。本ファイルを正本として読ませ、Codex で違う点（statusline・config.toml・Remote Control のシム方式）だけを差分表で持つ。**運用ルールを変えたら本ファイル側を直す**

> このドキュメント map が**全設定仕様の完全索引**。GO ゲート（`hi`）の auto-read は上記 1-8 の運用コアに絞り、それ以外（statusline-spec / profile / 各 docs）は本 map から必要時に参照する設計。

## User 個別事項

- Vim 未経験 → 2026-05-22 から LazyVim で始めた。`docs/nvim-manual.md` の「最初の 1 週間の使い方推奨」のフェーズ遷移を参考に進行中。
- 可処分時間: 朝晩各 1-2h。複雑すぎる設定は避け、実用最低ラインを優先。
- マルチモニター: 上 nvim、下 Claude Code（複数並列）。
- スタイル: 戦略コンサル風（結論 → 理由 → 具体アクション、比較表多用）。「凡庸な選択」を避ける指向。

## 参考: PATH 関連の教訓

過去に Claude Code の npm 版残骸でハマった経緯あり。PATH 変更後は **必ず新規ターミナル**で `where.exe <cmd>` 実体確認。物理削除のみ信頼（リネーム退避は再混入の温床）。同期で scoop と winget 重複した nvim も `scoop uninstall neovim` で物理削除済。
