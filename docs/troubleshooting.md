# トラブル対応記録

このリポジトリのセットアップで実際に遭遇した問題と解決策を残す。
**新規問題に当たったら必ず追記**（凡庸な選択を避けるための一次資料）。

---

## 1. 🔥 日本語 IME × Vim 風キーバインドが**動かない**

### 症状

- WezTerm のコピーモードで `h` `j` `k` `l` を押してもカーソル移動しない
- Neovim の Normal モードで hjkl やコマンドが効かない
- Esc を押しても Insert モードから抜けられない

### 原因

**Windows の IMM/TSF レイヤが、ASCII 文字キーを WezTerm/Neovim より先に奪っている**。

`config.use_ime = true`（WezTerm 設定）の場合、各アプリは IME を経由してキー入力を受け取る。IME が ON だと:

| キー | IME ON の挙動 |
|---|---|
| `h` `j` `k` `l` 等の文字 | IME がローマ字変換待ち状態にして握る → WezTerm/Neovim に届かない |
| 矢印キー `←↓↑→` | IME はスルー → 正常に届く |
| `Esc` | IME OFF は動作するが、その入力イベント自体が消費されることがあり Normal モード遷移しないことがある |
| `Ctrl+Shift+X` 等の修飾キー組合せ | IME はスルー → 正常に届く |

### 対策（優先順）

1. **コピーモード/Normal モードに入る前に必ず IME OFF**（`半角/全角` or `Alt+~`）
2. 矢印キーを使う（IME 影響なし）
3. **Neovim 側**: `:Tutor` で Esc 問題に当たったら `Ctrl+[` を Esc 代替として使う
4. 将来的に: 入口バインドで IME を強制 OFF する仕組み（Phase 4 検討事項）

### ステータス

- 2026-05-22: 矢印キーを WezTerm copy_mode に追加（hjkl と併設）

---

## 2. WezTerm 設定 reload しても古いハンドラが残る

### 症状

- `wezterm.lua` を編集して reload しても、過去の `wezterm.on("update-status", ...)` 等が画面に残骸を吐く
- `set_right_status` で旧 addon の文字列（`cwd=... branch=... ctx_remaining=...`）が出る

### 原因

`config.automatically_reload_config = true` は **config 値は再評価する**が、**`wezterm.on(...)` で登録した過去のイベントハンドラは解除しない**。
プロセスが生きてる限り、過去に登録した関数はメモリ上に残り続け、毎回 fire する。

### 対策

**WezTerm プロセスを完全に終了して再起動**（reload では不可）。
- 全タブ・ウィンドウを閉じる
- `Get-Process wezterm-gui` で残プロセス確認、必要に応じて `Stop-Process -Force`
- 新規 WezTerm 起動

### ステータス

- 2026-05-22: 確認・対処済み。`wezterm.lua` 内のコメントとしても明記。
- **2026-05-22 追記**: 透過率動的切替を試行錯誤する過程で同一セッション中に config reload を 30 回以上行った結果、過去の `update-status` ハンドラが蓄積し、`window_background_opacity` を md ペインだけで意図と逆の値（0.85）に書き換える現象が発生。**静的 `config.window_background_opacity = 0.95` 統一に方針変更後も、WezTerm を完全再起動するまで残骸ハンドラが上書きし続けた**。長時間のチューニングセッション後は WezTerm 再起動が必須。

---

## 3. コピーモード突入時に「画面下に謎のプロンプト」

### 症状

WezTerm の CopyMode に入った瞬間、ペイン下部に見覚えのない「プロンプトらしき表示」が出る。
たとえば:

```
❯  
─────────────────────────────────────────
  ◆ Opus 4.7 (1M context) │ ◈ ctx:19%/1M
  ▸ ~/Documents/...
```

### 原因

**Claude Code の TUI statusline**（=Claude Code が自分の画面下部に常時描いている情報帯）。
WezTerm が画面を**凍結**し、カーソルが下方向に navigable になるため、普段視界の隅で流れていたものが初めて目に止まる。

### 対策

不要。Claude Code の正常動作。コピーモードの仕様。

### ステータス

- 2026-05-22: 切り分け完了。`wezterm cli get-text` で各ペイン下部を吸い出して確認した。

---

## 4. nvim が winget と scoop で 2 系統並存

### 症状

`where.exe nvim` が 2 つのパスを返す:
- `C:\Program Files\Neovim\bin\nvim.exe` (winget)
- `C:\Users\81809\scoop\shims\nvim.exe` (scoop)

PATH 順で勝者が決まるが、片方が自動更新で先行すると silent にバージョンが切り替わる。Claude Code の npm 版残骸問題と**同型のリスク**。

### 対策

`scoop uninstall neovim` で物理削除し、`winget` に一本化（`initial-prompt.md` の意思決定に整合）。

### ステータス

- 2026-05-22: 完了。winget 0.12.2 単独構成。

---

## 6. Markdown のヘッダー/コードブロックに背景塗りが残る

### 症状

`lang.markdown` Extras 有効化後、`render-markdown.nvim` を `enabled = false` にしても、見出し行・コードブロック・引用ブロックの**背景色塗り**が消えない。Treesitter の文字色付けは効いているのにベタ塗り背景だけが残る。

### 原因

**2 つの罠が重なっていた**:

1. **`render-markdown.nvim` のさらに下層に、Treesitter の `@markup.*` ハイライトグループ自体に背景色が設定されている**。tokyonight などの colorscheme が下記グループに `bg` を入れているため、render-markdown を無効化しても下の層が残る:
   - `@markup.heading.1.markdown` 〜 `@markup.heading.6.markdown`
   - `@markup.raw.block.markdown`（コードフェンス）
   - `@markup.quote.markdown`
   - 旧 syntax 互換の `markdownH1`〜`markdownCodeBlock` も同様

2. **`ColorScheme` autocmd だけでは取り逃す**。LazyVim は起動時に colorscheme をロード → `ColorScheme` イベント発火、そのあとにプラグイン spec の `init` が走るため、**autocmd が登録される時点で ColorScheme は既に発火し終わっている**。よって登録した autocmd が一度も呼ばれず、bg=NONE 上書きが効かない。

### 対策

`init` で 3 イベントに同じ callback を登録する:

```lua
vim.api.nvim_create_autocmd("ColorScheme",   { pattern = "*",  callback = strip })
vim.api.nvim_create_autocmd("VimEnter",      { callback = strip })  -- 起動直後の決定打
vim.api.nvim_create_autocmd("FileType",      { pattern = { "markdown" }, callback = strip })
```

`VimEnter` が決定打で、起動直後の colorscheme ロード済状態で必ず実行される。`FileType markdown` は実際に md を開いた時の念押し。

### ステータス

- 2026-05-22: `nvim/lua/plugins/markdown.lua` で対処完了。`render-markdown.nvim` 自体は `enabled = false` のまま、Treesitter のグループ bg だけを上書き除去している。

---

## 5. 既存 `%LOCALAPPDATA%\nvim` が LazyVim ではなく手書き lazy.nvim 設定だった

### 症状

LazyVim スターターを入れる前提だったが、既に手書き lazy.nvim 設定が存在し（init.lua、lua/config、lua/plugins フル装備）、内容も非自明（gruvbox-material、LSP 手書き、neo-tree、Telescope 等）。

### 対策

2 重保全:
- ファイルシステム: `%LOCALAPPDATA%\nvim` → `%LOCALAPPDATA%\nvim-backup-2026-05-22`
- リポジトリ: `setup-neovim-wezterm\docs\legacy-nvim\` にコピー（Git 追跡で永久保存）

`%LOCALAPPDATA%\nvim-data` も同様に `-backup-2026-05-22` にリネーム。

### ステータス

- 2026-05-22: 完了。次フェーズで LazyVim スターターをクリーン導入予定。
