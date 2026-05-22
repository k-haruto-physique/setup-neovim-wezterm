-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- 現在のファイルを OS 既定アプリで開く (HTML→ブラウザ、PDF→Sumatra/Edge 等)
-- Space x o (external open)
vim.keymap.set("n", "<leader>xo", function()
    local filepath = vim.fn.expand("%:p")
    if filepath == "" then
        vim.notify("バッファがファイルに紐付いていません", vim.log.levels.WARN)
        return
    end
    -- Windows: start で OS 既定アプリ起動
    -- '"" は start にウィンドウタイトル空文字を渡すおまじない（パスが空白を含む時の対策）
    os.execute('start "" "' .. filepath .. '"')
    vim.notify("OS 既定アプリで開いた: " .. vim.fn.fnamemodify(filepath, ":t"), vim.log.levels.INFO)
end, { desc = "現在のファイルを OS 既定アプリで開く" })

-- カレントディレクトリをエクスプローラで開く
-- Space x e (external explorer)
vim.keymap.set("n", "<leader>xe", function()
    local cwd = vim.fn.getcwd()
    os.execute('start "" "' .. cwd .. '"')
end, { desc = "カレントディレクトリを Explorer で開く" })
