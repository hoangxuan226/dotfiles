return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          prepend_args = { "--config", vim.fn.expand("$HOME/.config/nvim/.markdownlint-cli2.yaml"), "--" },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    dependencies = { "mason.nvim" },
    lazy = true,
    opts = {
      formatters_by_ft = {
        json = { "prettier" },
        -- Imperative Configuration (Script-based)
        tmux = { "beautysh" },
        -- Declarative Configuration (Key-Value)
        kitty = { "shfmt" },
      },
    },
  },
}
