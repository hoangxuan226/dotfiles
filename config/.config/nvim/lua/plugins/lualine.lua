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

      -- Show 'V' if key layout is fcitx5 Bamboo
      table.insert(opts.sections.lualine_x, 2, {
        function()
          return require("config.fcitx5-cache").get_current_im()
        end,
      })

      -- Battery status
      table.insert(opts.sections.lualine_x, 3, {
        function()
          return require("plugins.lualine.battery").get_battery_status()
        end,
        cond = function()
          -- Only show if battery file exists
          return vim.fn.filereadable("/sys/class/power_supply/BAT1/capacity") == 1
        end,
      })
    end,
  },
}
