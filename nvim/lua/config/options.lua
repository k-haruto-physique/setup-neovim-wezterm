-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ターミナルウィンドウタイトルを「filename - NVIM (cwd)」に固定。
-- WezTerm のペイン表示で nvim と分かりやすくなる（透過率切替は静的化したが title は残す）。
vim.opt.title = true
vim.opt.titlestring = "%t - NVIM (%{getcwd()})"
