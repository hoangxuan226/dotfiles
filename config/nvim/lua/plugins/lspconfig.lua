local appearance = require("config.appearance")

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      -- Server configuration
      opts.servers = opts.servers or {}
      opts.servers.omnisharp = { enabled = false }

      -- Diagnostic UI configuration
      if appearance.border_style then
        opts.diagnostics = opts.diagnostics or {}
        opts.diagnostics.float = opts.diagnostics.float or {}
        opts.diagnostics.float.border = appearance.border_style
      end

      return opts
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      -- Custom registries
      opts.registries = {
        "github:mason-org/mason-registry",
        "github:Crashdummyy/mason-registry",
      }

      -- Ensure installed packages
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "roslyn" })

      -- UI configuration
      if appearance.border_style then
        opts.ui = opts.ui or {}
        opts.ui.border = appearance.border_style
      end

      return opts
    end,
  },
  "seblyng/roslyn.nvim",
  ---@module 'roslyn.config'
  ---@type RoslynNvimConfig
  opts = {
    -- your configuration comes here; leave empty for default settings
  },
}
