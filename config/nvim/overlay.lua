-- ~/.config/nvim/overlay.lua
-- For hammerspoon overlay (~/.hammerspoon/vim-overlay.lua)
-- minimal Neovim setup for quick editing in an overlay window.

-- ── Helpers ────────────────────────────────────────────────────────────
local DEBUG = false

-- Debugging: log to file
local function log_entry(msg)
  if not DEBUG then
    return
  end
  local f, err = io.open("/tmp/vim_overlay.log", "a")
  if not f then
    vim.schedule(function()
      vim.notify("Failed to open overlay log: " .. tostring(err), vim.log.levels.ERROR)
    end)
    return
  end
  local ts = os.date("%Y-%m-%d %H:%M:%S")
  f:write(string.format("[%s] %s\n", ts, msg))
  f:close()
end

log_entry("Vim overlay started")
-- ───────────────────────────────────────────────────────────────

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.notify("Please install lazy.nvim", vim.log.levels.ERROR)
  return
end

-- Make the plugin available to require() first
vim.opt.rtp:prepend(lazypath)

-- Minimal UI
vim.opt.number = false
vim.opt.relativenumber = false
vim.opt.signcolumn = "no"
vim.opt.showtabline = 0
vim.opt.laststatus = 0
vim.opt.cmdheight = 0
vim.opt.swapfile = false
vim.opt.undofile = false -- no persistent undo for temp buffers
vim.opt.fillchars = { eob = " " } -- replace ~ with blank space

-- transparent background
vim.api.nvim_set_hl(0, "Normal", { bg = "none" })

-- wrap long lines with proper break and showbreak
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.showbreak = "↪ "
vim.api.nvim_set_hl(0, "NonText", { fg = "#878996" }) -- showbreak color

-- keymaps for better navigation in wrapped lines
vim.keymap.set("n", "j", function()
  return vim.v.count == 0 and "gj" or "j"
end, { expr = true })
vim.keymap.set("n", "k", function()
  return vim.v.count == 0 and "gk" or "k"
end, { expr = true })

-- others
vim.opt.clipboard = "unnamedplus"
vim.keymap.set("n", "q", "<Nop>", { noremap = true, silent = true, desc = "Disable macro recording in register q" })

-- Plugins (lazy.nvim, minimal spec)
require("lazy").setup({
  spec = {
    {
      "folke/flash.nvim",
      keys = {
        {
          "s",
          mode = { "n", "x", "o" },
          function()
            require("flash").jump()
          end,
          desc = "Flash",
        },
      },
    },
  },
})

-- ── Handle overlay behavior ─────────────────────────────────────
-- Auto triggers Hammerspoon whenever the temp file is written
-- touch sentinel file to triggers Hammerspoon
local tmp_dir = os.getenv("HOME") .. "/.hammerspoon/vim-overlay-tmp"
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = tmp_dir .. "/vim_overlay.txt",
  callback = function()
    log_entry("Buffer written, syncing back to Hammerspoon")
    vim.fn.system("touch " .. tmp_dir .. "/vim_overlay_done")
  end,
  desc = "Sync overlay content back to Hammerspoon after save",
})

-- kepmap for command line: prevent accidental quit
vim.keymap.set("c", "<CR>", function()
  local cmd = vim.fn.getcmdline()
  if cmd == "q" then
    vim.schedule(function()
      vim.fn.system("kitten quick-access-terminal")
    end)
    return vim.api.nvim_replace_termcodes("<C-c>", true, false, true)
  elseif cmd == "wq" then
    vim.fn.setcmdline("w")
    return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
  end
  return vim.api.nvim_replace_termcodes("<CR>", true, false, true)
end, { expr = true })

-- prevent accidental quit via normal mode normal commands (ZZ, ZQ)
vim.keymap.set(
  "n",
  "ZZ",
  "<cmd>w<CR>",
  { noremap = true, silent = true, desc = "Save and hide overlay instead of quitting" }
)
vim.keymap.set("n", "ZQ", function()
  vim.fn.system("kitten quick-access-terminal")
end, { noremap = true, silent = true, desc = "Hide overlay without saving instead of quitting" })
