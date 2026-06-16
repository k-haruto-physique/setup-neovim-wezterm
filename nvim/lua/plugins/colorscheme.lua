-- WezTerm の Acrylic 透過を活かすため、nvim 側を透けさせる設定。
-- 既定の tokyonight に transparent=true を渡しつつ、それでも残る背景色を
-- ColorScheme autocmd で強制 NONE 化（プラグイン側で背景指定するものへの保険）。

return {
    -- LazyVim デフォルトの tokyonight を透過化
    {
        "folke/tokyonight.nvim",
        opts = {
            transparent = true,
            styles = {
                sidebars = "transparent",
                floats = "transparent",
            },
        },
    },

    -- LazyVim 本体 spec に init をぶら下げ、起動時 autocmd をまとめて登録する。
    --
    -- ⚠️ 重要: 同名 "LazyVim/LazyVim" spec を複数ファイルに分けて init を書くと、
    -- lazy.nvim は init を opts のようにマージせず last-wins で「最後の 1 つ」しか実行しない
    -- （他は黙って死ぬ）。以前は colorscheme.lua / markdown.lua×2 に init が分散し、
    -- 透過保険と conceallevel=0 が死んでいた。透過保険・conceallevel・markdown 背景剥がしを
    -- この 1 つの init に集約することで衝突を解消している。markdown.lua 側に init を戻さないこと。
    {
        "LazyVim/LazyVim",
        init = function()
            -- (1) 透過保険: 任意カラースキームでも主要群の背景を NONE 化
            vim.api.nvim_create_autocmd("ColorScheme", {
                pattern = "*",
                callback = function()
                    local groups = {
                        "Normal", "NormalNC",
                        "NormalFloat", "FloatBorder", "FloatTitle",
                        "SignColumn",
                        "EndOfBuffer", "MsgArea",
                        "LineNr", "CursorLineNr",
                        -- neo-tree
                        "NeoTreeNormal", "NeoTreeNormalNC", "NeoTreeEndOfBuffer",
                        "NeoTreeWinSeparator", "NeoTreeStatusLine",
                        -- telescope
                        "TelescopeNormal", "TelescopeBorder",
                        "TelescopePromptNormal", "TelescopePromptBorder",
                        "TelescopeResultsNormal", "TelescopeResultsBorder",
                        "TelescopePreviewNormal", "TelescopePreviewBorder",
                        -- which-key / notify
                        "WhichKey", "WhichKeyFloat",
                        "NotifyBackground",
                    }
                    for _, g in ipairs(groups) do
                        vim.api.nvim_set_hl(0, g, { bg = "NONE" })
                    end
                end,
            })

            -- (2) markdown では conceal をオフ（** や _ が表示/非表示で揺れないように）
            vim.api.nvim_create_autocmd("FileType", {
                pattern = { "markdown", "md" },
                callback = function()
                    vim.opt_local.conceallevel = 0
                end,
            })

            -- (3) markdown 系ハイライトの背景塗りを全て NONE（前景色は温存）。
            -- ColorScheme だけだとロード済テーマに fire しないため VimEnter / FileType でも再適用。
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
                    "@punctuation.special.markdown",
                }
                for _, g in ipairs(groups) do
                    pcall(vim.cmd, string.format("highlight %s guibg=NONE", g))
                end
            end
            vim.api.nvim_create_autocmd("ColorScheme", { pattern = "*", callback = strip_md_bg })
            vim.api.nvim_create_autocmd("VimEnter", { callback = strip_md_bg })
            vim.api.nvim_create_autocmd("FileType", { pattern = { "markdown" }, callback = strip_md_bg })
        end,
    },
}
