local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.notify("Please install lazy.nvim", vim.log.levels.ERROR)
  return
end

-- Make the plugin available to require() first
vim.opt.rtp:prepend(lazypath)

-- Add mason bin to PATH so conform.nvim can find formatters
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.expand("~/.local/share/nvim/mason/bin")

require("lazy").setup({
  spec = {
    {
      "seblyng/roslyn.nvim",
      opts = {},
    },
    {
      "stevearc/conform.nvim",
      opts = {
        format_on_save = {
          timeout_ms = 500,
          lsp_fallback = true,
        },
        formatters_by_ft = {
          lua = { "stylua" },
          javascript = { "prettier" },
          typescript = { "prettier" },
          markdown = { "prettier" },
          json = { "prettier" },
          tmux = { "beautysh" },
          kitty = { "shfmt" },
        },
      },
    },
    {
      "folke/flash.nvim",
      keys = {
        {
          "s",
          mode = { "n", "x", "o" },
          function()
            require("flash").jump()
          end,
          desc = "Flash",
        },
      },
    },
  },
})

vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2

vim.opt.clipboard = "unnamedplus"

-- Disable macro
vim.keymap.set("n", "q", "<Nop>", { noremap = true, silent = true, desc = "Disable macro recording in register q" })
