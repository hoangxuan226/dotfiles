return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      code = {
        -- language_border = " ", -- avoid showing the missmatched background color of the border
        width = "full",
        border = "thick",
        left_pad = 2,
        right_pad = 2,
      },
      indent = {
        enabled = true,
        skip_level = 0,
        skip_heading = true,
      },
    },
  },
}
