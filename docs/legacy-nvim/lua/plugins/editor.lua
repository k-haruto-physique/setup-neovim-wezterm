return {
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {},
  },
  {
    "numToStr/Comment.nvim",
    keys = {
      { "<C-_>", "<Plug>(comment_toggle_linewise_current)", mode = "n", desc = "Toggle comment" },
      { "<C-_>", "<Plug>(comment_toggle_linewise_visual)", mode = "v", desc = "Toggle comment" },
      { "<C-/>", "<Plug>(comment_toggle_linewise_current)", mode = "n", desc = "Toggle comment" },
      { "<C-/>", "<Plug>(comment_toggle_linewise_visual)", mode = "v", desc = "Toggle comment" },
      { "gcc", mode = "n", desc = "Toggle comment line" },
      { "gc", mode = { "n", "v" }, desc = "Toggle comment" },
    },
    opts = {},
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = { indent = { char = "│" }, scope = { enabled = false } },
  },
}
