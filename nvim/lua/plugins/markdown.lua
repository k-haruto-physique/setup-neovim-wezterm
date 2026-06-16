-- Markdown の見た目を素朴に: 背景塗りつぶし系の装飾はすべてオフ。
-- 文字の色分けは Treesitter シンタックスハイライトに任せる（プラグインなしで動く）。
--
-- ⚠️ conceallevel=0 と markdown 背景剥がし(strip_md_bg) の autocmd は
-- colorscheme.lua の単一 "LazyVim/LazyVim" init に集約済み。
-- ここに "LazyVim/LazyVim" spec を増やすと init が last-wins で衝突して死ぬので書かないこと。

return {
    -- LazyVim lang.markdown が入れる render-markdown.nvim を完全無効化
    -- 個別オプションでチューニングするより全停止のほうがクリーン
    {
        "MeanderingProgrammer/render-markdown.nvim",
        enabled = false,
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
