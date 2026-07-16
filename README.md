# setup-neovim-wezterm

Windows 11 上の Neovim + LazyVim + WezTerm 環境を、シンボリックリンクで dotfiles 管理するリポジトリ。

## 結論

- **リポジトリを正本、実体側 (`%LOCALAPPDATA%\nvim` 等) はシンボリックリンク**で運用する
- LazyVim をベースに、SQL / Markdown / Python を `:LazyExtras` で有効化（Lua はコア同梱で有効化不要）
- WezTerm 既存設定（タブバー上部、Acrylic 透過、自動リロード）は保持したまま統合

## 理由

| 観点 | シンボリックリンク方式 | コピー方式 |
|---|---|---|
| Git 追跡 | ◎ 編集が即時反映 | △ 同期スクリプト要 |
| 復元の容易さ | ◎ `mklink` 1 行 | × 手動コピー |
| 学習コスト | ○ 管理者権限が初回必要 | ◎ ファイル操作のみ |
| 中長期再現性 | ◎ | △ |

戦略上、「凡庸な選択」を避けつつ可処分時間 (朝晩各 1-2h) を圧迫しない最小構成を採る。

## ディレクトリ構成

```text
setup-neovim-wezterm/
├── README.md                  # 本ファイル
├── .gitignore
├── .claude/                   # Claude Code ハーネス設定（settings.json + hooks/）
├── nvim/                      # %LOCALAPPDATA%\nvim へリンク
│   ├── init.lua               # LazyVim スターター由来
│   ├── lua/
│   │   ├── config/            # autocmds, keymaps, options, lazy
│   │   └── plugins/           # カスタムプラグイン
│   ├── lazyvim.json           # LazyVim Extras 管理
│   ├── stylua.toml
│   └── .neoconf.json
├── wezterm/                   # %USERPROFILE%\.config\wezterm へリンク
│   └── wezterm.lua
├── powershell/
│   └── profile.ps1            # $PROFILE 用（dot-source）
├── claude/                    # Claude Code statusLine 一式
│   ├── statusline.ps1         # 正本（%USERPROFILE%\.claude\statusline.ps1 へ反映）
│   ├── statusline-spec.md     # 設計仕様
│   ├── CHANGELOG.md
│   └── README.md
└── docs/
    ├── initial-prompt.md      # 初回依頼内容
    ├── nvim-manual.md         # Neovim/LazyVim 実用ガイド（VSCode 対応表つき）
    ├── keybinds.md            # 全キーバインド一覧（網羅版）
    ├── cheatsheet-1page.md    # 毎日使う最小キー 1 枚（常時表示/印刷用）
    ├── cheatsheet.html        # 印刷用 1 枚（md が正本）
    ├── backlog.md             # 未完タスクの単一台帳（GO ゲート回収）
    ├── lang-workflows.md      # 言語別実戦フロー（SQL/Python/Markdown/Lua）
    ├── vim-mental-model.md    # 「動詞+名詞」文法など思考モデル（初心者向け）
    ├── practice-drills.md     # Phase 別の具体練習メニュー
    ├── troubleshooting.md     # トラブル対応記録
    └── legacy-nvim/           # 過去の手書き lazy.nvim 設定（参考保全）
```

### 実体配置

| リポジトリ側（正本） | 実体側（リンク） | コマンド |
|---|---|---|
| `setup-neovim-wezterm\nvim` | `%LOCALAPPDATA%\nvim` | `mklink /D` |
| `setup-neovim-wezterm\wezterm\wezterm.lua` | `%USERPROFILE%\.config\wezterm\wezterm.lua` | `mklink` |
| `setup-neovim-wezterm\claude\statusline.ps1` | `%USERPROFILE%\.claude\statusline.ps1` | `mklink` |
| `setup-neovim-wezterm\powershell\profile.ps1` | `$PROFILE`（dot-source） | `. <path>`（管理者不要） |

シンボリックリンク作成は **PowerShell 管理者権限** が必要（`powershell\profile.ps1` のみ symlink でなく `$PROFILE` からの dot-source 方式で管理者不要）。

## セットアップ手順（概要）

手順の正本は本 README の Phase 別セクション（トラブル時の経緯は `docs/troubleshooting.md`）。

### Phase 1: 環境準備（完了済み）

- [x] Neovim インストール (`winget install Neovim.Neovim`)
- [x] JetBrainsMono Nerd Font インストール
- [ ] WezTerm `wezterm.lua` へのフォント反映確認
- [ ] 依存ツール (Git, Node.js, ripgrep, fd) 確認

### Phase 2: LazyVim 導入

1. 依存ツール確認
2. 既存 `%LOCALAPPDATA%\nvim` のバックアップ（存在時のみ）
3. リポジトリ内 `nvim/` に LazyVim スターターを clone → `.git` 削除
4. `%LOCALAPPDATA%\nvim` からシンボリックリンク作成
5. `wezterm.lua` をリポジトリへ移動 + シンボリックリンク化
6. 初回 `nvim` 起動でプラグイン自動 DL
7. `:checkhealth` で動作確認

### Phase 3: 基本操作習得

- `:Tutor` を実行
- 必須キーバインドを `docs/keybinds.md` に整理

### Phase 4: 開発用カスタマイズ

- `:LazyExtras` で `lang.sql` / `lang.markdown` / `lang.python` を有効化（`lang.lua` は LazyVim コア同梱のため有効化不要）
- 日本語 IME × Esc 問題の対処
- WezTerm + Neovim + Claude Code の連携
- `powershell/profile.ps1` にエイリアス追加

## 編集対象の主言語

**SQL (PostgreSQL/PostGIS), Markdown, Lua, Python**

## トラブル対応の指針

直近の教訓（Claude Code npm 版残骸問題）から：

- PATH 関連変更後は **必ず新規ターミナル**で確認
- 実体は `where.exe <cmd>` で確認
- 削除前に `Get-ChildItem` で事前チェック
- 「物理削除のみ」を信頼する（リネーム/退避は再混入の温床）

## 環境

- OS: Windows 11 (build 26200)
- ターミナル: WezTerm
- シェル: PowerShell（cmd.exe は使用しない）— `wezterm.lua` の `default_prog = { "pwsh.exe", "-NoLogo" }` で明示。**未指定だと WezTerm は cmd.exe を起動し `powershell/profile.ps1` が読まれない**（2026-07-16 是正・troubleshooting #15）
- パッケージ管理: winget
- Claude Code: ネイティブ版 2.1.211（`C:\Users\81809\.local\bin\claude.exe`・自動更新有効）
  - **全対話セッションが既定で Remote Control**。正本は `~/.claude/settings.json` の `"remoteControlAtStartup": true`（毎回 `--remote-control` を付けるのと等価・起動経路に非依存）。素で起動したい時だけ設定を切るか `disableRemoteControl`。セッション名に当日日付を付けたい時は `remote [name]` → `20260716-…`（troubleshooting #16）
