-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("n", "<leader>0", Snacks.dashboard.open, { desc = "Open mini starter" })

-- Disable keymaps
vim.keymap.set("n", "q", "<Nop>", { noremap = true, silent = true, desc = "Disable macro recording in register q" })

-- Custom keymaps
require("config.custom-keymaps.find-directory")
require("config.custom-keymaps.yank-cmds")
require("config.custom-keymaps.dap")
require("config.custom-keymaps.neotest")
