-- Markdown の見た目を素朴に: 背景塗りつぶし・conceal をオフ。
-- 「ちかちか感」を消す目的。シンタックスハイライトは Treesitter に任せる。

return {
    -- LazyVim lang.markdown が入れる render-markdown.nvim を素朴化
    {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
            heading = {
                -- 見出し行の背景色を無効化
                backgrounds = {},
                -- 左マージンの装飾アイコンも無効化
                signs = {},
            },
            code = {
                -- コードブロックの背景塗りを無効化
                style = "language",  -- "full" (背景塗り) → "language" (右上に言語名のみ)
                sign = false,
                border = "none",
            },
            quote = {
                -- 引用ブロックの装飾を控えめに
                repeat_linebreak = false,
            },
            -- パイプ表のセル背景も控えめに
            pipe_table = {
                style = "normal",  -- "full" (装飾あり) より控えめ
            },
        },
    },

    -- markdown ファイルでは conceal をオフにして
    -- ** や _ などのマーカーが「表示されたり消えたり」しないようにする
    {
        "LazyVim/LazyVim",
        init = function()
            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "markdown", "md" },
                callback = function()
                    vim.opt_local.conceallevel = 0
                    -- スペル校正もオフ（赤線が目に来る場合）
                    -- vim.opt_local.spell = false
                end,
            })
        end,
    },

    -- markdownlint-cli2 の lint を無効化（厳しすぎて目障り）
    -- シンタックスハイライト・LSP・フォーマットは生かしたまま、診断のみオフ。
    {
        "mfussenegger/nvim-lint",
        opts = function(_, opts)
            opts.linters_by_ft = opts.linters_by_ft or {}
            opts.linters_by_ft.markdown = {}
            return opts
        end,
    },
}
