return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    cmd = "Neotree",
    keys = {
      { "<C-b>", "<cmd>Neotree toggle<CR>", desc = "Toggle file tree" },
      { "<leader>e", "<cmd>Neotree reveal<CR>", desc = "Reveal in tree" },
    },
    opts = {
      close_if_last_window = true,
      window = { width = 32 },
      filesystem = {
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = { visible = true, hide_dotfiles = false, hide_gitignored = false },
      },
      default_component_configs = {
        indent = { with_markers = true },
        git_status = { symbols = { added = "+", modified = "~", deleted = "-", renamed = "➜" } },
      },
    },
  },
}
