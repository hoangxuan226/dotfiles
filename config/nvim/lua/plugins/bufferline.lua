return {
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        always_show_bufferline = true,
        show_buffer_close_icons = false,
        numbers = "buffer_id",
        indicator = {
          style = "underline",
        },
        separator_style = "slope", -- "slant" | "slope" | "thick" | "thin" | { 'any', 'any' }
        diagnostics = "nvim_lsp",
        show_duplicate_prefix = true, -- whether to show duplicate buffer prefix
      },
    },
  },
}
