-- ~/.hammerspoon/vim-overlay.lua

-- ── Config ─────────────────────────────────────────────────────────────
local DEBUG = false

-- Kitty
local KITTY_TITLE = "kitty-quick-access" -- default title of panel created by `kitten quick-access-terminal`

-- Apps where the overlay should never appear.
local IGNORED_APPS = {
	[KITTY_TITLE] = true,
	["kitty"] = true,
	["Terminal"] = true,
	["Spotlight"] = true,
}

-- Temp
local PATH_WATCHER = os.getenv("HOME") .. "/.hammerspoon/vim-overlay-tmp/"
local TEMP_FILE = PATH_WATCHER .. "vim_overlay.txt"
local SENTINEL = PATH_WATCHER .. "vim_overlay_done"

-- Nvim
local NVIM_OVERLAY_INIT = os.getenv("HOME") .. "/.config/nvim/overlay.lua"
local NVIM_SOCKET = "/tmp/nvim-overlay.sock"

-- Command
local TOGGLE_KITTY_PANEL_CMD = "kitten quick-access-terminal"
local START_OVERLAY_CMD =
	string.format("%s nvim -u %s --listen %s %s", TOGGLE_KITTY_PANEL_CMD, NVIM_OVERLAY_INIT, NVIM_SOCKET, TEMP_FILE)
local RESET_NVIM_BUFFER =
	string.format("nvim --server %s --remote-send '<Esc>:e! %s<CR>' 2>/dev/null", NVIM_SOCKET, TEMP_FILE)

-- ── State ──────────────────────────────────────────────────────────────
local previousApp = nil -- app to return focus to after paste-back

-- ── Helpers ────────────────────────────────────────────────────────────
local function dprint(...)
	if DEBUG then
		print(...)
	end
end

local function notify(msg)
	hs.alert.show(msg, 1.5)
end

-- Get the focused axuielement.
local function getFocusedInfo()
	-- Use frontmostApplication instead of walking the AX tree (el:attributeValue("AXWindow")).
	-- This completely skips heavy IPC UI-crawling overhead and avoids lagging/timeouts on bloated apps.
	local app = hs.application.frontmostApplication()
	local sys = hs.axuielement.systemWideElement()
	local _, el = pcall(function()
		return sys:attributeValue("AXFocusedUIElement")
	end)
	return app, el
end

-- Get overlay panel (hs.application).
local function getOverlayApp()
	return hs.application.get(KITTY_TITLE)
end

-- toggle overlay visibility.
-- show: nil = toggle, true = show, false = hide
local function toggleOverlay(lines, show)
	local app = getOverlayApp()

	-- Kitty quick access terminal has not started, do nothing
	if app == nil then
		dprint("[toggleOverlay] Quick access terminal not started, doing nothing.")
		return
	end

	local isShowing = #app:allWindows() > 0
	if show ~= nil then
		if show and isShowing then
			dprint("[toggleOverlay] Requested to show, but it is already showing. Ignoring.")
			return
		elseif not show and not isShowing then
			dprint("[toggleOverlay] Requested to hide, but it is already hidden. Ignoring.")
			return
		end
	end

	lines = tonumber(lines) -- Ensure lines is safely treated as a number
	lines = math.max(1, lines or 1) -- Enforce a minimum of 1 line

	local cmd = TOGGLE_KITTY_PANEL_CMD .. string.format(" -o lines=%d", lines)
	dprint("[toggleOverlay] Executing command: " .. cmd)
	local task = hs.task.new(os.getenv("SHELL"), function(code)
		dprint("[toggleOverlay] Command exited with code: " .. tostring(code))
	end, { "-l", "-c", cmd })

	if not task:start() then
		dprint("[toggleOverlay] ERROR: Failed to start the task!")
	end
end

-- Launch overlay Kitty and wait for the nvim socket to appear (max 4s).
-- Async: calls callback(true) when ready, callback(false) on timeout.
local function ensureOverlayRunning(callback)
	-- nvim socket already exists — overlay is running and ready
	if hs.fs.attributes(NVIM_SOCKET) then
		dprint("[ensureOverlayRunning] socket already exists, skipping launch")
		callback(true)
		return
	end

	-- This case won't happen with the current setup, but still recovery:
	-- The panel has started but the socket is missing
	-- Kill the existing kitty so that a fresh launch can succeed.
	local app = getOverlayApp()
	if app then
		app:kill9()
	end

	-- Neither socket nor panel — full fresh launch
	dprint("[ensureOverlayRunning] launching overlay Kitty asynchronously")

	local task = hs.task.new(os.getenv("SHELL"), function(code)
		dprint("[ensureOverlayRunning] overlayTask exited, code: " .. tostring(code))
	end, { "-l", "-c", START_OVERLAY_CMD })

	if not task:start() then
		dprint("[ensureOverlayRunning] ERROR: Failed to start the task!")
	end

	local elapsed = 0
	local poller
	poller = hs.timer.doEvery(0.2, function()
		elapsed = elapsed + 0.2
		if hs.fs.attributes(NVIM_SOCKET) then
			dprint("[ensureOverlayRunning] nvim socket appeared after " .. string.format("%.1f", elapsed) .. "s")
			poller:stop()
			callback(true)
		elseif elapsed >= 4 then
			dprint("[ensureOverlayRunning] timed out after 4s")
			poller:stop()
			notify("Overlay Kitty failed to start")
			callback(false)
		end
	end)
end

-- ── Snapshot current field text into temp file ─────────────────────────
-- Returns the number of lines in the text, which is used to size the overlay panel.
local function snapshotFieldText(el)
	local text = ""
	if el then
		local ok, val = pcall(function()
			return el:attributeValue("AXValue")
		end)
		text = (ok and type(val) == "string") and val or ""
	else
		notify("Cannot get focused element")
	end

	local lines = 0
	if text and text ~= "" then
		-- Count occurrences of newlines and add 1
		local _, newlineCount = text:gsub("\n", "\n")
		lines = newlineCount + 1
	end

	local f = io.open(TEMP_FILE, "w")
	if f then
		f:write(text)
		f:close()
	end

	return lines
end

-- ── Reset Neovim buffer to load the fresh temp file ───────────────────
local function resetNvimBuffer()
	local sock = hs.fs.attributes(NVIM_SOCKET)
	if not sock then
		dprint("[resetNvimBuffer] nvim socket not found at expected path: " .. NVIM_SOCKET)
		notify("nvim socket not found")
		return false
	end
	local task = hs.task.new(os.getenv("SHELL"), function(code)
		dprint("[resetNvimBuffer] resetTask exited, code: " .. tostring(code))
	end, { "-l", "-c", RESET_NVIM_BUFFER })

	if not task:start() then
		dprint("[resetNvimBuffer] ERROR: Failed to start the task!")
	end
	return true
end

-- ── Paste-back: temp file → clipboard → real field ────────────────────
local function pasteBack()
	local f = io.open(TEMP_FILE, "r")
	if not f then
		return
	end
	local text = f:read("*a")
	f:close()

	-- Strip trailing newline that nvim appends on write
	text = text:gsub("\n$", "")

	hs.pasteboard.setContents(text)

	if not previousApp then
		dprint("[pasteBack] No previous app to return focus to")
		return
	end

	if previousApp:activate() then
		dprint("[pasteBack] app activated successfully, sending keystrokes")
		hs.eventtap.keyStroke({ "cmd" }, "a", 50000) -- select all existing text
		hs.eventtap.keyStroke({ "cmd" }, "v", 50000) -- paste
	else
		dprint("[pasteBack] Failed to activate previous app")
	end
end

-- ── Show overlay ──────────────────────────────────────────────────────
local function showOverlay()
	local app, focusedEl = getFocusedInfo()
	local name = (app and app:name()) or ""
	dprint("[showOverlay] app: " .. name)
	if IGNORED_APPS[name] then
		notify("Overlay ignored for: " .. name)
		return
	end

	ensureOverlayRunning(function(ready)
		if not ready then
			dprint("[showOverlay] callback return false, aborting showOverlay")
			notify("Overlay not found")
			return
		end
		if not resetNvimBuffer() then
			return
		end

		previousApp = app
		local lines = snapshotFieldText(focusedEl)
		toggleOverlay(lines, true)
	end)
end

-- ── Hide overlay ──────────────────────────────────────────────────────
local function hideOverlay()
	toggleOverlay(nil, false)
end

-- ── Sentinel watcher: Neovim signals paste-back is ready ──────────────
local sentinelWatcher = hs.pathwatcher
	.new(PATH_WATCHER, function()
		if hs.fs.attributes(SENTINEL) then
			dprint("[watcher] triggered for SENTINEL")
			os.remove(SENTINEL)
			pasteBack()
			hideOverlay()
		end
	end)
	:start()

-- Prevent Lua Garbage Collection from silently killing them
_G.__vimOverlayWatcher = sentinelWatcher

-- ── Hotkey (F19 sent by Karabiner) ────────────────────────────────────
hs.hotkey.bind({}, "F19", showOverlay)

M = {}
M.getFocusedInfo = function()
	hs.timer.doAfter(3, function()
		local app, el = getFocusedInfo()
		print(app and app:name() or "nil", hs.inspect(el))
	end)
end

return M
