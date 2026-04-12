local appearance = require("config.appearance")

return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      -- LSP functionality configuration
      opts.lsp = opts.lsp or {}
      opts.lsp.progress = {
        enabled = false,
      }

      -- UI configuration
      if appearance.border_style then
        opts.presets = opts.presets or {}
        opts.presets.lsp_doc_border = true
      end

      return opts
    end,
  },
}
