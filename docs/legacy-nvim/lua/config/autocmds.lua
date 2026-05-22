local aug = vim.api.nvim_create_augroup("UserAutocmds", { clear = true })

-- Highlight yanked text briefly
vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- Terminal buffer: no numbers, enter insert mode automatically
vim.api.nvim_create_autocmd("TermOpen", {
  group = aug,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd("startinsert")
  end,
})

-- Auto-open claude in a right-side vertical split on startup.
-- Skip when nvim is opened for a specific file (only trigger for `nvim`, `nvim .`, `nvim <dir>`).
vim.api.nvim_create_autocmd("VimEnter", {
  group = aug,
  callback = function()
    if vim.g.claude_pane_opened then return end

    local argc = vim.fn.argc()
    local first = argc > 0 and vim.fn.argv(0) or ""
    local is_dir_or_empty = argc == 0 or (first ~= "" and vim.fn.isdirectory(first) == 1)
    if not is_dir_or_empty then return end

    if vim.fn.executable("claude") == 0 then return end

    vim.schedule(function()
      local main_win = vim.api.nvim_get_current_win()
      vim.cmd("botright vsplit")
      local width = math.floor(vim.o.columns * 0.4)
      vim.cmd("vertical resize " .. width)
      vim.cmd("terminal claude")
      vim.g.claude_pane_opened = true
      vim.api.nvim_set_current_win(main_win)
    end)
  end,
})
