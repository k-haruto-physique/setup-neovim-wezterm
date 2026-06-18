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

読み込み完了後、短い挨拶を返す（読んだファイル名の列挙は不要）。**ただし `docs/backlog.md` の OPEN 件数と上位 2-3 項目を挨拶に必ず含める**（例:「準備できた。OPEN 5 件（statusline 再リンク / open-path 実機確認 / dadbod 可視確認 …）。何をやる?」）。質問されてから読むのでは遅い。

## Purpose

Windows 11 上の Neovim + LazyVim + WezTerm 環境を symlink で dotfiles 管理するリポジトリ。本リポジトリが**正本**で、`%LOCALAPPDATA%\nvim` と `%USERPROFILE%\.config\wezterm\wezterm.lua` はここへの symlink。

## CRITICAL: 編集ワークフロー

- **編集は必ずリポジトリ側のパス**で行う:
  - `setup-neovim-wezterm/nvim/...`
  - `setup-neovim-wezterm/wezterm/wezterm.lua`
  - `setup-neovim-wezterm/claude/statusline.ps1`（Claude Code statusLine。`%USERPROFILE%\.claude\statusline.ps1` へ symlink。**仕様・履歴は同じ `claude/` に集約**: `statusline-spec.md`・`CHANGELOG.md`・`README.md`。2026-06-18 に旧独立リポ `Repositories/statusline` を合体・退役）
- 実体側 (`%LOCALAPPDATA%\nvim` 等) 経由で Edit ツールを叩くと **`Refusing to write through symlink` エラー**が出る。リポジトリ側パスへ切り替えること。
- symlink 構成は管理者権限 PowerShell で作成済。再構築が必要なら `docs/troubleshooting.md` 参照。

## リロード挙動

- **WezTerm**: `config.automatically_reload_config = true`。ファイル保存で即座に再読込。ただし `wezterm.on(...)` 登録イベントハンドラは reload で**解除されない**ため、addon 系の挙動変更は WezTerm の完全再起動（プロセス kill）が必要なケースがある。
- **Neovim**: `:Lazy reload <plugin>` か `:qa` → `nvim` 再起動が確実。

## WezTerm の透過率（現状: 静的 0.95 統一 / nvim 検出は廃止済）

透過率は静的 `config.window_background_opacity = 0.95`（`wezterm/wezterm.lua`）で統一。
**nvim ペインを検出して透過率を動的切替する仕組み（`pane_is_nvim()` / OSC 1337 `IS_NVIM` 送信 / 0.85↔0.95 切替）は実装していない**。当初は動的切替を検討したが Windows TUI で `get_user_vars()`・title・foreground プロセス検出のいずれも不安定（LSP 子プロセスが一瞬 foreground を奪う等）で廃止した。経緯は `docs/troubleshooting.md` 第 2 項。

残っているのは次の 2 つのみ:
- `nvim/lua/config/options.lua` の `titlestring = "%t - NVIM (%{getcwd()})"`（ペイン名で nvim を視認しやすくする用途。透過率制御には未使用）
- `wezterm.lua` の `update-status` ハンドラが、過去 addon ハンドラ残骸による opacity 書換えを抑止するため毎フレーム 0.95 を明示 override

## キーバインド（このリポジトリ独自）

- `Ctrl+Shift+X` → CopyMode（明示バインド）。突入時カーソル黄色化で視認。
- `Ctrl+Shift+I` → 新規 WezTerm ウィンドウで `nvim .`（マルチモニター運用向け、上モニター用）
- `Ctrl+Shift+N` → 新規ウィンドウで `claude`（下モニターで複数 claude 用）
- Neovim: `<leader>xo` = OS 既定アプリで開く（HTML→ブラウザ、PDF→Edge 等）/ `<leader>xe` = エクスプローラで cwd 開く

CopyMode key_table は明示定義: 矢印キーを優位 + hjkl 併設。`PageUp/Down/Home/End` も同様の理由で追加。`n`/`N` で検索マッチ間ジャンプ（検索開始は `Ctrl+Shift+F` のみ）。**意図しない検索バー誤発火を防ぐため `/` `?` は `act.Nop` で無効化**（検索パターンのリセットは検索バー内 `Ctrl+U`）。

## 編集対象言語

SQL (PostgreSQL/PostGIS), Python, Markdown, Lua  
LazyVim Extras 有効化済: `lang.sql`, `lang.python`, `lang.markdown`（lang.lua はコアに同梱・有効化不要）

## 重要な gotcha

- **IME × Vim キー**: 日本語 IME ON 中は `h`/`j`/`k`/`l` が IME に奪われ、CopyMode・Normal モードで動かない。矢印キーは IME 透過。詳細 `docs/troubleshooting.md` 第 1 項。
- **WezTerm reload とイベントハンドラ残骸**: 旧 Claude Code addon 等の `wezterm.on()` が config reload では消えない。完全再起動が必要。詳細 `docs/troubleshooting.md` 第 2 項。
- **`Search:` バー誤発火**: `act.CopyMode("ClearPattern")` を Multiple action 内で呼ぶと副作用で search overlay が出る。**ClearPattern は使わない**。
- **CopyMode key_table 上書きの罠**: `config.key_tables.copy_mode = {...}` は WezTerm デフォルトを完全置換（fall through しない）。必要なキーは全て自前で定義する。

## カスタムプラグイン構成

`nvim/lua/plugins/` 配下:
- `colorscheme.lua` — tokyonight `transparent = true` + 全主要 highlight 群を `bg = NONE` に上書きする ColorScheme autocmd
- `markdown.lua` — render-markdown.nvim を素朴化（heading/code/quote 背景塗りを全停止）、conceallevel=0、**markdownlint-cli2 の lint を無効化**（フォーマットは継続）
- `ui-clean.lua` — vim-illuminate を背景塗りなしの細い underline のみに

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
- `docs/legacy-nvim/` — 旧 lazy.nvim 設定の参照保全

## User 個別事項

- Vim 未経験 → 2026-05-22 から LazyVim で始めた。`docs/nvim-manual.md` の「最初の 1 週間の使い方推奨」のフェーズ遷移を参考に進行中。
- 可処分時間: 朝晩各 1-2h。複雑すぎる設定は避け、実用最低ラインを優先。
- マルチモニター: 上 nvim、下 Claude Code（複数並列）。
- スタイル: 戦略コンサル風（結論 → 理由 → 具体アクション、比較表多用）。「凡庸な選択」を避ける指向。

## 参考: PATH 関連の教訓

過去に Claude Code の npm 版残骸でハマった経緯あり。PATH 変更後は **必ず新規ターミナル**で `where.exe <cmd>` 実体確認。物理削除のみ信頼（リネーム退避は再混入の温床）。同期で scoop と winget 重複した nvim も `scoop uninstall neovim` で物理削除済。
