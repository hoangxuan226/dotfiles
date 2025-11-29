-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

require("config.evkey")

if vim.g.vscode then
  -- VSCode extension
  local vscode = require("vscode")
  vscode.notify("✅ Neovim config loaded in VSCode in WSL!")
else
  -- ordinary Neovim
end
