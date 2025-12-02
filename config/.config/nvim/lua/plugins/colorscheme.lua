return {
  -- #region tokyonight
  -- {
  --   "folke/tokyonight.nvim",
  --   lazy = true,
  --   opts = {
  --     transparent = true,
  --     styles = {
  --       sidebars = "transparent",
  --       floats = "transparent",
  --     },
  --     on_highlights = function(hl)
  --       hl.WinSeparator = {
  --         fg = "#ff966c",
  --       }
  --       hl.BufferLineSeparator = {
  --         fg = "#1e2030",
  --       }
  --       hl.TabLineFill = {} -- empty to set background to transparent
  --       hl.BufferLineTabSeparator = {
  --         fg = "#1e2030",
  --       }
  --       hl.WinBar = {} -- empty to set background to transparent
  --     end,
  --   },
  -- },
  -- #endregion tokyonight

  -- #region gruvbox
  -- add gruvbox
  -- {
  --   "ellisonleao/gruvbox.nvim",
  --   lazy = true,
  --   opts = {
  --     transparent_mode = true,
  --     palette_overrides = {
  --       bright_green = "#db986e",
  --     },
  --   },
  -- },
  -- #endregion gruvbox

  -- #region catppuccin
  {
    "catppuccin/nvim",
    lazy = true,
    name = "catppuccin",
    opts = {
      -- flavour = "frappe",
      transparent_background = true,
      float = {
        transparent = true, -- enable transparent floating windows
        -- solid = true, -- use solid styling for floating windows, see |winborder|
      },
      lsp_styles = {
        underlines = {
          errors = { "undercurl" },
          hints = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
        },
      },
      integrations = {
        aerial = true,
        alpha = true,
        cmp = true,
        dashboard = true,
        flash = true,
        fzf = true,
        grug_far = true,
        gitsigns = true,
        headlines = true,
        illuminate = true,
        indent_blankline = { enabled = true },
        leap = true,
        lsp_trouble = true,
        mason = true,
        mini = true,
        navic = { enabled = true, custom_bg = "lualine" },
        neotest = true,
        neotree = true,
        noice = true,
        notify = true,
        snacks = true,
        telescope = true,
        treesitter_context = true,
        which_key = true,
      },
    },
    specs = {
      {
        "akinsho/bufferline.nvim",
        optional = true,
        opts = function(_, opts)
          if (vim.g.colors_name or ""):find("catppuccin") then
            opts.highlights = require("catppuccin.special.bufferline").get_theme()
          end
        end,
      },
    },
  },
  -- #endregion catppuccin

  -- Configure LazyVim to load
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
  -- border highlight when background is transparent
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      opts.window = {
        completion = {
          border = "rounded",
          winhighlight = "Normal:MyHighlight",
          winblend = 0,
        },
        documentation = {
          border = "rounded",
          winhighlight = "Normal:MyHighlight",
          winblend = 0,
        },
      }
    end,
  },
  {
    "mason-org/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        float = {
          border = "rounded",
        },
      },
    },
  },
}
