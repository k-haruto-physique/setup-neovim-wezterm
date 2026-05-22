-- Markdown の見た目を素朴に: 背景塗りつぶし系の装飾はすべてオフ。
-- 文字の色分けは Treesitter シンタックスハイライトに任せる（プラグインなしで動く）。

return {
    -- LazyVim lang.markdown が入れる render-markdown.nvim を完全無効化
    -- 個別オプションでチューニングするより全停止のほうがクリーン
    {
        "MeanderingProgrammer/render-markdown.nvim",
        enabled = false,
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

    -- Treesitter / 旧 syntax / tokyonight が markdown 系グループに乗せている bg を全て NONE に。
    -- foreground 色だけは温存して、塗りつぶしだけを消す。
    -- ColorScheme イベントだけだと取り逃す（既にロード済の colorscheme には fire しない）ので、
    -- FileType markdown と VimEnter でも明示的に再適用する。
    {
        "LazyVim/LazyVim",
        init = function()
            local function strip_md_bg()
                local groups = {
                    -- Treesitter (nvim >= 0.10 の @markup.* 系)
                    "@markup.heading", "@markup.heading.markdown",
                    "@markup.heading.1", "@markup.heading.1.markdown",
                    "@markup.heading.2", "@markup.heading.2.markdown",
                    "@markup.heading.3", "@markup.heading.3.markdown",
                    "@markup.heading.4", "@markup.heading.4.markdown",
                    "@markup.heading.5", "@markup.heading.5.markdown",
                    "@markup.heading.6", "@markup.heading.6.markdown",
                    "@markup.raw", "@markup.raw.block",
                    "@markup.raw.markdown", "@markup.raw.markdown_inline",
                    "@markup.raw.block.markdown", "@markup.raw.delimiter.markdown",
                    "@markup.quote", "@markup.quote.markdown",
                    "@markup.list", "@markup.list.markdown",
                    "@markup.link", "@markup.link.label.markdown",
                    "@markup.link.url.markdown",
                    -- 旧 syntax グループ
                    "markdownH1", "markdownH2", "markdownH3",
                    "markdownH4", "markdownH5", "markdownH6",
                    "markdownH1Delimiter", "markdownH2Delimiter",
                    "markdownH3Delimiter", "markdownH4Delimiter",
                    "markdownH5Delimiter", "markdownH6Delimiter",
                    "markdownHeadingDelimiter",
                    "markdownCode", "markdownCodeBlock", "markdownCodeDelimiter",
                    "markdownBlockquote", "markdownListMarker",
                    -- 念のため: コードフェンス全般
                    "@punctuation.special.markdown",
                }
                for _, g in ipairs(groups) do
                    pcall(vim.cmd, string.format("highlight %s guibg=NONE", g))
                end
            end

            -- 1. ColorScheme 変更時（カラーテーマ切替も拾う）
            vim.api.nvim_create_autocmd("ColorScheme", {
                pattern = "*",
                callback = strip_md_bg,
            })
            -- 2. VimEnter (起動直後、colorscheme ロード済の状態で実行)
            vim.api.nvim_create_autocmd("VimEnter", {
                callback = strip_md_bg,
            })
            -- 3. FileType markdown（実際に md 開いた時、念押し）
            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "markdown" },
                callback = strip_md_bg,
            })
        end,
    },
}
