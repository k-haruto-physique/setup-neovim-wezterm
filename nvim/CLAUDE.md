# nvim/ の注意（nvim/ 配下を触るときだけ読み込まれる）

ルートの `CLAUDE.md` から 2026-09-15 に移設。全体ルール（編集はリポジトリ側パス・IME 注意など）はルート側。
このフォルダは `%LOCALAPPDATA%\nvim` から symlink されている（本ファイルは Neovim には無視される）。

## リロード

`:Lazy reload <plugin>` か `:qa` → `nvim` 再起動が確実。

## カスタムプラグイン構成の意図

`lua/plugins/` 配下:
- `colorscheme.lua` — tokyonight `transparent = true` + 全主要 highlight 群を `bg = NONE` に上書きする ColorScheme autocmd
- `markdown.lua` — render-markdown.nvim を**完全無効化**（`enabled = false`）+ **markdownlint-cli2 の lint を無効化**（conform のフォーマットは継続）。conceallevel=0 と markdown 背景剥がしは `colorscheme.lua` の単一 `LazyVim/LazyVim` init に集約済（**同名 spec の init は last-wins で黙って消える** → troubleshooting #11。init を複数ファイルに分けて書かない）
- `ui-clean.lua` — vim-illuminate を背景塗りなしの細い underline のみに
