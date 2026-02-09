return {
  {
    "folke/snacks.nvim",
    config = function(_, opts)
      require("snacks").setup(opts)

      -- Apply image rendering fixes
      require("config.snacks.fix-image-preview")()
      require("config.snacks.fix-picker-ghost-image")()
    end,
    opts = {
      dashboard = {
        preset = {
          header = [[
██╗  ██╗██╗   ██╗ █████╗ ███╗   ██╗
╚██╗██╔╝██║   ██║██╔══██╗████╗  ██║
 ╚███╔╝ ██║   ██║███████║██╔██╗ ██║
 ██╔██╗ ██║   ██║██╔══██║██║╚██╗██║
██╔╝ ██╗╚██████╔╝██║  ██║██║ ╚████║
╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝
                                   ]],
        },
      },
      -- image = {
      -- inline = false,
      -- enabled = false,
      -- formats = {},
      -- },
      terminal = {
        win = {
          position = "float",
          height = 0.7,
          width = 0.7,
          border = "rounded",
        },
      },
    },
  },
}
