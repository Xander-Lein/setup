vim.g.mapleader = " "
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.termguicolors = true

vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Сохранить файл" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Закрыть окно" })
