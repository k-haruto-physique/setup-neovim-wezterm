-- snacks.nvim の explorer（LazyVim 既定の「Space e」で開くファイラ）の隠しファイル表示設定。
-- このリポジトリは dotfiles 管理が主目的なので、. 始まり（.claude / .gitignore 等）を既定で表示する。
-- gitignore 対象（__pycache__ / .venv / *.html 等のノイズ）は隠したまま。
--
-- 一時トグル（explorer の「一覧」にカーソルがある状態で・入力欄ではない）:
--   H = 隠しファイル（dotfiles）の表示/非表示
--   I = gitignore 対象の表示/非表示
-- ※ R（リフレッシュ）は neo-tree のキーで、snacks explorer には無い。
--
-- 補足: neo-tree は `:Neotree` コマンドで別途開ける（lua/plugins/neo-tree.lua で .claude 表示済み・キーバインドは未割当）。

return {
    {
        "folke/snacks.nvim",
        opts = {
            picker = {
                sources = {
                    explorer = {
                        hidden = true,   -- . 始まり（.claude 等）を常に表示
                        ignored = false, -- gitignore 対象は隠す（ビルド生成物のノイズ回避）
                        -- ツリーの幅（桁数）。snacks の sidebar プリセット既定は 40。
                        -- 数字を上げれば広がる。min_width <= width で揃える。
                        layout = { layout = { width = 50, min_width = 50 } },
                    },
                },
            },
        },
    },
}
