return {
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    event = "VeryLazy",
    opts = function(_, opts)
      -- Integrate CodeCompanion spinner into lualine
      table.insert(opts.sections.lualine_x, {
        require("plugins.codecompanion.lualine-spinner"),
      })

      -- Model info
      table.insert(opts.sections.lualine_x, {
        require("plugins.codecompanion.lualine-model"),
      })
    end,
  },
}
