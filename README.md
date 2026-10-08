# setup-neovim-wezterm

Windows 11 上の Neovim + LazyVim + WezTerm 環境を、シンボリックリンクで dotfiles 管理するリポジトリ。

## PC が壊れたとき（復旧の入口）

このリポは、PC 全体を立て直すときの入口です。新しい PC にあるのは、GitHub・Google ドライブ・自宅の外付け SSD だけ、という前提で書いています。新品の PC を買ったときも同じ手順です。

0. **最初に入れる物**（新しい PC の「ターミナル」＝Windows PowerShell で、1 行ずつ）。

   ```powershell
   winget install --id Microsoft.PowerShell -e
   winget install --id Git.Git -e
   winget install --id GitHub.cli -e
   irm https://claude.ai/install.ps1 | iex
   ```

   入れ終わったらターミナルを閉じて開き直し（新しい PATH を読ませる）、`pwsh` で PowerShell 7 に入って次を打つ。

   ```powershell
   mkdir $HOME\Documents\Repositories; cd $HOME\Documents\Repositories
   git clone https://github.com/k-haruto-physique/setup-neovim-wezterm
   cd setup-neovim-wezterm; claude
   ```

   Claude Code が開いたら、ブラウザで claude.ai にログインする。
1. Claude に「PC が壊れたので、README の『PC が壊れたとき』の手順で立て直したい」と頼む。以下は Claude が順に進める（決まりは `CLAUDE.md` の「このリポの役目」）。
2. `gh auth login` で GitHub にログインする。
3. 人生管理用の非公開リポを clone する（名前は `gh repo list` で確かめる）。続けて、その中の `harness/` に、Claude のセッション運用の非公開ハブのリポを clone する（別のリポ・名前は同じく `gh repo list`。人生管理のリポはこのフォルダを無視する設定なので、clone しないと中身が無い）。
4. その非公開リポの `.pc_backup/README.md` の順に戻す（設定・MCP・常駐タスク・memory）。鍵やパスワードは控えに入っていないので、パスワード管理ソフトから入れ直す。
5. このリポの設定（nvim・WezTerm・PowerShell・statusline）は、下の「実体配置」の表どおりにリンクを張り直す。
6. Slack の投稿役は、鍵を資格情報マネージャーにしまい直すだけで戻る。メンションで Claude を動かす受け口（`slack/listen.py`）は、アプリの鍵をしまい直し、対応表を人生管理の非公開リポの控えから戻し、自動起動を登録し直す（`slack/README.md` の「メンションで動かす」手順 3・6・7。Slack 側の設定は残っている）。

⚠️ 外付け SSD は、ドライブ文字だけで決めない。別の USB メモリが同じ文字になることがある。SSD にしか無いフォルダがあるかを見てから読み書きする。

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
├── Codex/                     # Codex 用（タブバーのステータス・Remote Control・Claude ⇄ Codex ブリッジ）
│   ├── tabbar-status.ps1       # タブバー用ステータス書き出し（全Codexを1プロセスで担当）
│   ├── register-tabbar-status-task.ps1 # 上をログオンタスクで常駐（wezterm から起動すると 0xc0000142・#29）
│   ├── statusline-spec.md      # データ源・数値・色の仕様
│   ├── CHANGELOG.md            # 変更履歴
│   ├── statusline.toml         # [tui].status_line の正本スニペット
│   ├── runtime.toml            # 自動承認の正本スニペット
│   ├── remote-control.ps1      # ログオン時の Remote Control 常駐タスク
│   ├── ask-codex.ps1           # Claude → Codex ブリッジ（会話へ送信し最終返答を返す）
│   ├── ask-claude.ps1          # Codex → Claude ブリッジ（待受中の Claude へ送信し返答を待つ）
│   ├── claude-listen.ps1       # Claude 側の待受（1 通受けたら終了＝セッションを起こす）
│   ├── claude-reply.ps1        # Claude 側の返答
│   ├── bridge-common.ps1       # Codex → Claude ブリッジの共通処理（受信箱 %LOCALAPPDATA%\Temp\codex-claude-bridge）
│   ├── register-remote-control-task.ps1 # 自動起動タスクの登録
│   └── README.md
├── slack/                     # Slack へ投稿役（ボット）の名前で投稿する道具（鍵はリポ外）
│   ├── post.py
│   ├── bot-icon.png
│   └── README.md               # 作り方と、PC を作り直したときの戻し方
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
| `setup-neovim-wezterm\Codex\statusline.toml` | `%USERPROFILE%\.codex\config.toml` の `[tui]` | 手動マージ |
| `setup-neovim-wezterm\Codex\runtime.toml` | `%USERPROFILE%\.codex\config.toml` のトップレベル | 手動マージ |
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
- Antigravity CLI（`agy`・Google の Gemini を端末から使う道具。旧 Gemini CLI の後継）: 1.2.16（`%LOCALAPPDATA%\agy\bin\agy.exe`・2026-10-05 導入・以後は自分で更新する）
  - 個人の Google アカウントでの Gemini CLI は 2026-06-18 に終了した。`gemini` は `IneligibleTierError` で止まり、入れ直しても戻らない（troubleshooting #31）。npm の `@google/gemini-cli` は 2026-10-05 に削除済み。
  - 入れ方: 自分の pwsh で `irm https://antigravity.google/cli/install.ps1 | iex`（管理者不要・ユーザーの PATH にも足す）。Claude の自動モードはこのインストールを止めるので、本人が打つ（Claude Code の中なら `! pwsh -NoProfile -Command "irm https://antigravity.google/cli/install.ps1 | iex"`）。
  - ログイン: **新しいターミナル**で `agy` を起動 → ブラウザで Google アカウントにログイン → ブラウザに出たコードを `agy` のターミナルへ貼る（チャットには貼らない）。鍵は Windows 資格情報マネージャーに入る。
  - 使い方: 頭出しなしは `agy -p "..."`（旧 `gemini -p`）。画像はプロンプトの中に `@ファイル名`。全体の決まり `~/.gemini/GEMINI.md` はそのまま読まれる。設定は `~/.gemini/antigravity-cli/settings.json`。ほかのリポのセッション向けの案内は `~/.claude/CLAUDE.md`「Gemini に相談するとき」。
