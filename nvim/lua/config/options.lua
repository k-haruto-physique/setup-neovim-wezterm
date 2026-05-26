-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- ターミナルウィンドウタイトルを「filename - NVIM (cwd)」に固定。
-- WezTerm のペイン表示で nvim と分かりやすくなる（透過率切替は静的化したが title は残す）。
vim.opt.title = true
vim.opt.titlestring = "%t - NVIM (%{getcwd()})"

-- dadbod-ui の DB 接続定義（pgAdmin 的な接続ツリー）。
-- :DBUIToggle で最初からこの接続が出る（:DBUIAddConnection 不要）。
-- 重要: データは postgres ではなく kanro_db にある（2026-05-26 判明）。
-- パスワードはここに書かない。%APPDATA%\postgresql\pgpass.conf で認証する。
vim.g.dbs = {
    { name = "kanro_db (local)", url = "postgresql://postgres@localhost:5432/kanro_db" },
}

-- PostgreSQL クライアント (psql) を nvim 自身の PATH に通す保険。
-- 親 WezTerm が PATH 追記より前に起動していると、子 nvim から psql が見えず dadbod が DB に繋げない。
-- nvim 起動時に bin を明示追加する（重複は回避）。これで WezTerm 完全再起動なしでも psql が効く。
local pg_bin = "C:\\Program Files\\PostgreSQL\\18\\bin"
if vim.fn.isdirectory(pg_bin) == 1 and not string.find(vim.env.PATH or "", pg_bin, 1, true) then
    vim.env.PATH = (vim.env.PATH or "") .. ";" .. pg_bin
end
