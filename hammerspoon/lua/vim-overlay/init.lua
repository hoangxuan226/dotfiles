-- ── Config ─────────────────────────────────────────────────────────────
local log = require("lua.logger").new("VimOverlay", "info")
local constants = require("lua.vim-overlay.share")

-- Apps where the overlay should never appear.
local IGNORED_APPS = {
	["kitty-quick-access"] = true,
	["kitty"] = true,
	["Terminal"] = true,
	["Spotlight"] = true,
}

-- Kitty
local MIN_LINES = 5
local MAX_LINES = 5

-- Nvim
local NVIM_OVERLAY_INIT = os.getenv("HOME") .. "/.hammerspoon/lua/vim-overlay/nvim-init.lua"
local NVIM_SOCKET = "/tmp/nvim-overlay.sock"

-- Command
local START_OVERLAY_CMD = string.format(
	"%s -o start_as_hidden=yes nvim -u %s --listen %s %s",
	constants.TOGGLE_KITTY_PANEL_CMD,
	NVIM_OVERLAY_INIT,
	NVIM_SOCKET,
	constants.TEMP_FILE
)
local RESET_NVIM_BUFFER =
	string.format("nvim --server %s --remote-send '<Esc>:e! %s<CR>' 2>/dev/null", NVIM_SOCKET, constants.TEMP_FILE)

-- ── State ──────────────────────────────────────────────────────────────
local previousApp = nil -- app to return focus to after paste-back
local overlayPid = nil -- PID of the kitty instance running the overlay

-- ── Helpers ────────────────────────────────────────────────────────────
local function notify(msg)
	hs.alert.show(msg, 1.5)
end

-- Get the focused axuielement.
local function getFocusedInfo()
	local sys = hs.axuielement.systemWideElement()
	local _, el = pcall(function()
		return sys:attributeValue("AXFocusedUIElement")
	end)

	-- hs.application.frontmostApplication() cannot return Spotlight,
	-- because Spotlight's panels run as background processes and don't become "frontmost",
	-- so traverse from the focused element to get the app.
	local app = nil
	if el then
		local pid = el:pid()
		if pid then
			app = hs.application.get(pid)
		end
	end

	-- Fallback to frontmostApplication
	if not app then
		app = hs.application.frontmostApplication()
	end

	return app, el
end

-- Get overlay panel (hs.application).
local function getOverlayApp()
	return hs.application.get(overlayPid)
end

-- toggle overlay visibility.
-- show: nil = toggle, true = show, false = hide
local function toggleOverlay(lines, show)
	local app = getOverlayApp()

	-- Kitty quick access terminal has not started, do nothing
	if app == nil then
		log.d("[toggleOverlay] Quick access terminal not started, doing nothing.")
		return
	end

	local isShowing = #app:allWindows() > 0
	if show ~= nil then
		if show and isShowing then
			log.d("[toggleOverlay] Requested to show, but it is already showing. Ignoring.")
			return
		elseif not show and not isShowing then
			log.d("[toggleOverlay] Requested to hide, but it is already hidden. Ignoring.")
			return
		end
	end

	lines = tonumber(lines) -- Ensure lines is safely treated as a number
	lines = math.max(MIN_LINES, math.min(MAX_LINES, lines or 1))

	local cmd = constants.TOGGLE_KITTY_PANEL_CMD .. string.format(" -o lines=%d", lines)
	log.d("[toggleOverlay] Executing command: " .. cmd)
	local task = hs.task.new(os.getenv("SHELL"), function(code)
		log.d("[toggleOverlay] Command exited with code: " .. tostring(code))
	end, { "-c", cmd })

	if not task:start() then
		log.d("[toggleOverlay] ERROR: Failed to start the task!")
	end
end

-- Launch overlay Kitty and wait for the nvim socket to appear (max 4s).
-- Async: calls callback(true) when ready, callback(false) on timeout.
local function ensureOverlayRunning(callback)
	-- nvim socket already exists — overlay is running and ready
	if hs.fs.attributes(NVIM_SOCKET) then
		log.d("[ensureOverlayRunning] socket already exists, skipping launch")
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
	log.d("[ensureOverlayRunning] launching overlay Kitty asynchronously")

	local task = hs.task.new(os.getenv("SHELL"), function(code)
		log.d("[ensureOverlayRunning] overlayTask exited, code: " .. tostring(code))
	end, { "-c", START_OVERLAY_CMD })
	log.d("[ensureOverlayRunning] Starting task with command: " .. START_OVERLAY_CMD)

	if not task:start() then
		log.d("[ensureOverlayRunning] ERROR: Failed to start the task!")
	end

	local elapsed = 0
	local poller
	local findPidCmd = string.format("pgrep -f '%s'", constants.KITTY_INSTANCE_GROUP)
	log.d("[ensureOverlayRunning] command to find PID: " .. tostring(findPidCmd))
	poller = hs.timer.doEvery(0.2, function()
		elapsed = elapsed + 0.2

		local output = hs.execute(findPidCmd)
		overlayPid = tonumber(output:match("%d+"))
		log.d("[ensureOverlayRunning] PID of kitty: " .. tostring(overlayPid))
		if overlayPid and hs.fs.attributes(NVIM_SOCKET) then
			log.d("[ensureOverlayRunning] nvim socket appeared after " .. string.format("%.1f", elapsed) .. "s")
			poller:stop()
			callback(true)
		elseif elapsed >= 4 then
			log.d("[ensureOverlayRunning] timed out after 4s")
			poller:stop()
			notify("Overlay Kitty failed to start")
			callback(false)
		end
	end)
end

-- ── Snapshot current field text into temp file ─────────────────────────
-- Returns the number of lines in the text, which is used to size the overlay panel.
local function snapshotFieldText(el)
	if not el then
		log.d("[snapshotFieldText] No element provided")
		return -1
	end

	local text = ""
	local ok, val = pcall(function()
		return el:attributeValue("AXValue")
	end)
	text = (ok and type(val) == "string") and val or ""

	local lines = 0
	if text and text ~= "" then
		-- Count occurrences of newlines and add 1
		local _, newlineCount = text:gsub("\n", "\n")
		lines = newlineCount + 1
	end

	local f = io.open(constants.TEMP_FILE, "w")
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
		log.d("[resetNvimBuffer] nvim socket not found at expected path: " .. NVIM_SOCKET)
		notify("nvim socket not found")
		return false
	end
	local task = hs.task.new(os.getenv("SHELL"), function(code)
		log.d("[resetNvimBuffer] resetTask exited, code: " .. tostring(code))
	end, { "-l", "-c", RESET_NVIM_BUFFER })

	if not task:start() then
		log.d("[resetNvimBuffer] ERROR: Failed to start the task!")
	end
	return true
end

-- ── Paste-back: temp file → clipboard → real field ────────────────────
local function pasteBack()
	local f = io.open(constants.TEMP_FILE, "r")
	if not f then
		return
	end
	local text = f:read("*a")
	f:close()

	-- Strip trailing newline that nvim appends on write
	text = text:gsub("\n$", "")

	hs.pasteboard.setContents(text)

	if not previousApp then
		log.d("[pasteBack] No previous app to return focus to")
		return
	end

	if previousApp:activate() then
		log.d("[pasteBack] app activated successfully, sending keystrokes")
		hs.eventtap.keyStroke({ "cmd" }, "a", 50000) -- select all existing text
		hs.eventtap.keyStroke({ "cmd" }, "v", 50000) -- paste
	else
		log.d("[pasteBack] Failed to activate previous app")
	end
end

-- ── Show overlay ──────────────────────────────────────────────────────
local function showOverlay()
	local app, focusedEl = getFocusedInfo()
	local name = (app and app:name()) or ""
	log.d("[showOverlay] app: " .. name .. ", el: " .. (focusedEl and focusedEl:attributeValue("AXRole") or "nil"))
	if IGNORED_APPS[name] then
		notify("Overlay ignored for: " .. name)
		return
	end

	local lines = snapshotFieldText(focusedEl)
	if lines < 0 then
		notify("Failed to snapshot field text")
		return
	end

	ensureOverlayRunning(function(ready)
		if not ready then
			log.d("[showOverlay] callback return false, aborting showOverlay")
			notify("Overlay not found")
			return
		end
		if not resetNvimBuffer() then
			return
		end

		previousApp = app
		toggleOverlay(lines, true)
	end)
end

-- ── Hide overlay ──────────────────────────────────────────────────────
local function hideOverlay()
	toggleOverlay(nil, false)
end

-- ── Sentinel watcher: Neovim signals paste-back is ready ──────────────
local sentinelWatcher = hs.pathwatcher
	.new(constants.PATH_WATCHER, function()
		if hs.fs.attributes(constants.SENTINEL) then
			log.d("[watcher] triggered for SENTINEL")
			os.remove(constants.SENTINEL)
			pasteBack()
			hideOverlay()
		end
	end)
	:start()

-- Prevent Lua Garbage Collection from silently killing them
_G.__vimOverlayWatcher = sentinelWatcher

return {
	Show = showOverlay,
	Hide = hideOverlay,
	Focus = function()
		print("Please focus some app/field within 3 seconds to see debug info in console...")
		hs.timer.doAfter(3, function()
			local app, el = getFocusedInfo()
			local pid = (app and app:pid()) or "N/A"
			local name = (app and app:name()) or ""
			local role = (el and el:attributeValue("AXRole")) or ""
			print("Focused app: (" .. pid .. ") " .. name .. ", el:" .. role)

			local attributes = el:attributeNames()
			print("el's attributes:" .. hs.inspect(attributes))
		end)
	end,
}
