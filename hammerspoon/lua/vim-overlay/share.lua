local M = {}
M.KITTY_INSTANCE_GROUP = "hammerspoon_vim_overlay"
M.TOGGLE_KITTY_PANEL_CMD = string.format(
	"/Applications/kitty.app/Contents/MacOS/kitten quick-access-terminal --instance-group=%s",
	M.KITTY_INSTANCE_GROUP
)
M.PATH_WATCHER = os.getenv("HOME") .. "/.hammerspoon/vim-overlay-tmp/"
M.TEMP_FILE = M.PATH_WATCHER .. "vim_overlay.txt"
M.SENTINEL = M.PATH_WATCHER .. "vim_overlay_done"
return M
