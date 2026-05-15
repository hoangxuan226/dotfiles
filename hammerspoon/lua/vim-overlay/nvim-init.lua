-- Minimal Neovim setup for hammerspoon vim-overlay.
local hammerspoon_path = vim.fn.expand("~/.hammerspoon/lua/vim-overlay")
package.path = hammerspoon_path .. "/?.lua;" .. hammerspoon_path .. "/?/init.lua;" .. package.path

local lazy_path = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazy_path) then
	vim.notify("Please install lazy.nvim", vim.log.levels.ERROR)
	return
end

-- Make the plugin available to require() first
vim.opt.rtp:prepend(lazy_path)

-- ── Debugging ──────────────────────────────────────────────────────────
local DEBUG = false

-- Debugging: log to file
local debug_log_file = "/tmp/vim_overlay.log"
local logger = nil
if not DEBUG then
	os.remove(debug_log_file) -- clear log on each start unless debugging
else
	logger = require("profile_debug.logger")
end

local function log_entry(msg)
	if not DEBUG then
		return
	end
	return logger and logger.log_entry(debug_log_file, msg)
end

log_entry("Vim overlay started")

-- Debug LSP tree on VimLeave
require("profile_debug.lsp_tree").setup()

-- ───────────────────────────────────────────────────────────────
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
local function safe_require(name)
	local ok, res = pcall(require, name)
	if not ok then
		log_entry("require('" .. name .. "') failed: " .. tostring(res))
		return nil
	end
	return res
end
log_entry("Loading Hammerspoon config for Vim overlay")
local constants = safe_require("share")
if not constants then
	-- abort further setup, view log for details
	return
end
log_entry("Temp file path: " .. constants.TEMP_FILE)
log_entry("Sentinel file path: " .. constants.SENTINEL)
vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = constants.TEMP_FILE,
	callback = function()
		local touch_cmd = "touch " .. constants.SENTINEL
		vim.fn.system(touch_cmd)
		log_entry("Buffer written, syncing back to Hammerspoon: " .. touch_cmd)
	end,
	desc = "Sync overlay content back to Hammerspoon after save",
})

-- keymap for command line: prevent accidental quit
vim.keymap.set("c", "<CR>", function()
	local cmd = vim.fn.getcmdline()
	if cmd == "q" then
		vim.schedule(function()
			vim.fn.system(constants.TOGGLE_KITTY_PANEL_CMD)
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
	vim.fn.system(constants.TOGGLE_KITTY_PANEL_CMD)
end, { noremap = true, silent = true, desc = "Hide overlay without saving instead of quitting" })
