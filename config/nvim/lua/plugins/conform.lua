return {
  {
    "stevearc/conform.nvim",
    dependencies = { "mason.nvim" },
    lazy = true,
    opts = {
      formatters_by_ft = {
        zsh = { "beautysh" },
        json = { "prettier" },
        -- Imperative Configuration (Script-based)
        tmux = { "beautysh" },
        -- Declarative Configuration (Key-Value)
        kitty = { "shfmt" },
      },
    },
  },
}
