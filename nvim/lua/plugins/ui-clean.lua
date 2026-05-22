-- UI 装飾を素朴化: 塗りつぶし系を「うっすら」に。

return {
    -- vim-illuminate: 背景塗りやめて細いアンダーラインだけにする
    {
        "RRethy/vim-illuminate",
        init = function()
            -- ColorScheme 読み込み後に highlight 上書き（カラースキーム変更にも追従）
            vim.api.nvim_create_autocmd("ColorScheme", {
                pattern = "*",
                callback = function()
                    -- 背景なし・グレーの細い下線のみ
                    local style = { bg = "NONE", underline = true, sp = "#666666" }
                    vim.api.nvim_set_hl(0, "IlluminatedWordText",  style)
                    vim.api.nvim_set_hl(0, "IlluminatedWordRead",  style)
                    vim.api.nvim_set_hl(0, "IlluminatedWordWrite", style)
                end,
            })
        end,
    },

    -- LSP 診断ハイライトもごく薄に（赤波線は残すが背景塗りは外す）
    {
        "neovim/nvim-lspconfig",
        opts = {
            diagnostics = {
                virtual_text = true,   -- 行末メッセージ: 残す
                underline = true,      -- 波線: 残す
                signs = true,          -- 行頭アイコン: 残す
                update_in_insert = false,
            },
        },
    },
}
