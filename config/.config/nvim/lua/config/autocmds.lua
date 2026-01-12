-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

if vim.g.vscode then
  -- VSCode extension
  local vscode = require("vscode")
  vscode.notify("✅ Neovim config loaded in VSCode in WSL!")
  -- require("config.autocmds.evkey-im-switch")
else
  -- ordinary Neovim
  require("config.autocmds.fcitx5-im-switch").setup()
end
