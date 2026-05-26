-- neo-tree（Space e のファイラ）の隠しファイル表示を調整。
-- このリポジトリは dotfiles 管理が主目的なので、. 始まり（.claude 等）を既定で表示する。
-- ただし .git 内部と gitignore 対象（__pycache__ / .venv 等のノイズ）は隠したまま。
-- すべてを一時的に出したい時は neo-tree 内で H（大文字）でトグル。

return {
    {
        "nvim-neo-tree/neo-tree.nvim",
        opts = {
            filesystem = {
                filtered_items = {
                    visible = false,         -- フィルタ対象を薄く出すかどうか（今回は dotfiles を非フィルタ化するので false で十分）
                    hide_dotfiles = false,   -- . 始まりを隠さない（.claude / .gitignore 等を表示）
                    hide_gitignored = true,  -- gitignore 対象は隠す（ビルド生成物のノイズ回避）
                    hide_by_name = { ".git" }, -- .git の内部ディレクトリだけは隠す
                },
            },
        },
    },
}
