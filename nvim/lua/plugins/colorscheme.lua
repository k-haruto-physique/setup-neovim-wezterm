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

    -- 任意のカラースキームに対しても保険として全主要群を透過化
    {
        "LazyVim/LazyVim",
        init = function()
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
        end,
    },
}
