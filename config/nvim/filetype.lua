vim.filetype.add({
  -- based on filename
  -- filename = {
  --   ["tmux.conf"] = "tmux",
  --   [".tmux.conf"] = "tmux",
  --   ["kitty.conf"] = "kitty",
  -- },

  -- based on pattern
  pattern = {
    -- files .conf in ~/.config/tmux/ or ~/config/tmux/ will be tmux
    [".*/[%.]*config/tmux/.*%.conf"] = "tmux",
    -- files .conf in ~/.config/kitty/ or ~/config/tmux/ will be kitty
    [".*/[%.]*config/kitty/.*%.conf"] = "kitty",
  },
})
