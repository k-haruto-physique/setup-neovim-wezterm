# Neovim + LazyVim + WezTerm セットアップ依頼

## あなたの役割

WindowsにNeovim + LazyVimをセットアップし、`setup-neovim-wezterm` リポジトリでdotfiles管理する。WezTerm既存設定との統合も含む。戦略コンサル風のトーン、結論→理由→具体アクションの構造で回答。

## 作業ディレクトリ

`C:\Users\81809\Documents\Repositories\setup-neovim-wezterm`（`git init` 済み）

## 目指す最終的なディレクトリ構成

```text
setup-neovim-wezterm/
├── README.md                  # 構成意図・セットアップ手順・トラブル対応
├── .gitignore
├── nvim/                      # %LOCALAPPDATA%\nvim と同期
│   ├── init.lua               # LazyVim エントリポイント（スターター由来）
│   ├── lua/
│   │   ├── config/            # LazyVim 設定（autocmds, keymaps, options, lazy）
│   │   └── plugins/           # カスタムプラグイン設定
│   ├── lazyvim.json           # LazyVim Extras 管理
│   ├── stylua.toml
│   └── .neoconf.json
├── wezterm/                   # %USERPROFILE%\.config\wezterm と同期
│   └── wezterm.lua            # 既存設定（タブバー下端、Acrylic透過、自動リロード）
├── powershell/
│   └── profile.ps1            # $PROFILE 用（リポジトリ移動エイリアス等）
└── docs/
    ├── initial-prompt.md      # このファイル
    ├── setup.md               # 初回セットアップログ
    ├── keybinds.md            # 覚えるべきキーバインド一覧
    └── troubleshooting.md     # トラブル対応記録
```

### 実体配置の方針

- `%LOCALAPPDATA%\nvim` ← シンボリックリンク → `setup-neovim-wezterm\nvim`
- `%USERPROFILE%\.config\wezterm\wezterm.lua` ← シンボリックリンク → `setup-neovim-wezterm\wezterm\wezterm.lua`
- `mklink /D` および `mklink` を使用（PowerShell 管理者権限）
- リポジトリ側を正本、実体側はリンクとして運用

## Windows環境

- OS: Windows 11 (build 26200)
- ユーザー: `C:\Users\81809`
- ターミナル: WezTerm（既存設定 `C:\Users\81809\.config\wezterm\wezterm.lua` あり、`automatically_reload_config = true`、タブバー下端配置、Acrylic透過、`use_fancy_tab_bar = false`、カスタムタブ装飾、IME有効）
- シェル: PowerShell主体（cmd.exe は使用しない）
- Claude Code: ネイティブ版 2.1.147、`C:\Users\81809\.local\bin\claude.exe`（自動更新有効、`Config install method: native`、警告ゼロ）
- パッケージ管理: winget

## 編集対象の主言語

**SQL（PostgreSQL/PostGIS）、Markdown、Lua、Python**

Phase 4 で `:LazyExtras` により上記言語のサポートを有効化する。

## 既に完了している作業

1. ✅ Neovim インストール（`winget install Neovim.Neovim`）
2. ✅ JetBrainsMono Nerd Font インストール
3. ⚠️ WezTerm `.config\wezterm\wezterm.lua` にフォント追加 → **未確認**
4. ⚠️ 依存ツール（Git、Node.js、ripgrep、fd） → **未確認**

## 実施フェーズ

### Phase 2: LazyVim導入

1. 依存ツール確認（`nvim`, `git`, `node`, `rg`, `fd`）
2. 既存 `%LOCALAPPDATA%\nvim` のバックアップ（存在時のみ）
3. リポジトリ内 `nvim/` に LazyVim スターターをクローン
4. `.git` 削除
5. `%LOCALAPPDATA%\nvim` から `setup-neovim-wezterm\nvim` へのシンボリックリンク作成
6. 既存 `wezterm.lua` をリポジトリ内 `wezterm/` に移動、シンボリックリンクで置換
7. 初回 `nvim` 起動でプラグイン自動DL
8. `:checkhealth` で動作確認

### Phase 3: 基本操作習得

- 私が `:Tutor` を実行、あなたは伴走
- 必須キーバインドを `docs/keybinds.md` に整理

### Phase 4: 開発用カスタマイズ

- `:LazyExtras` で `lang.sql`, `lang.markdown`, `lang.python`, `lang.lua` を有効化
- 日本語IME × Esc問題の対処
- WezTerm + Neovim + Claude Code の連携
- `powershell/profile.ps1` にエイリアス追加

## 制約・嗜好

- 可処分時間は朝晩各1-2時間
- 複雑すぎる設定は避ける（実用最低ラインを優先）
- 中長期的な再現性・Git追跡を重視
- 「凡庸な選択」は避ける
- やらない方がいいことは明確に指摘
- 抽象論ではなくコマンドレベルまで落とす
- Vim未経験、開発スキル中級

## 回答スタイル

- 結論 → 理由 → 具体アクション の順
- メリット / デメリット、リスク / 対策を提示
- 比較表・優先順位を活用
- 各Stepで「何を貼ってほしいか」明示
- 日本語、段階的進行を優先

## 最初のタスク

以下の順序で進めてください:

1. **`README.md` ドラフトを作成**: 上記ディレクトリ構成図・セットアップ意図・現状ステータスを記載
2. **`.gitignore` を作成**: Neovim/Lua系の標準的な除外設定
3. **Phase 2 Step 1: 依存ツール確認**: PowerShellコマンドを提示、結果を私が貼って次へ

## トラブル履歴

直近2日でClaude Codeのnpm版残骸問題に遭遇済み。PATH関連は新規ターミナル必須・`where.exe` で実体確認・`Get-ChildItem` で事前確認・物理削除のみ信頼、を徹底。