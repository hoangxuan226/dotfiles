vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

vim.opt.clipboard = "unnamedplus"

-- Disable macro
vim.keymap.set("n", "q", "<Nop>", { noremap = true, silent = true, desc = "Disable macro recording in register q" })
