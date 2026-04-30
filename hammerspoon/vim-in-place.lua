-- ~/.hammerspoon/vim-in-place.lua

-- ── Config ─────────────────────────────────────────────────────────────
local DEBUG = false
local clickHints = require("click-hints")

local Modes = {
	NORMAL = "NORMAL",
	VISUAL = "VISUAL",
	INSERT = "INSERT",
}

local icons = {
	[Modes.NORMAL] = hs.styledtext.new("[ N ]", { color = { red = 0.64, green = 0.75, blue = 0.55 } }), -- Green (Nord)
	[Modes.VISUAL] = hs.styledtext.new("[ V ]", { color = { red = 0.71, green = 0.56, blue = 0.68 } }), -- Purple (Nord)
	[Modes.INSERT] = hs.styledtext.new("[ I ]", { color = { red = 0.53, green = 0.75, blue = 0.82 } }), -- Blue (Nord)
}

local excludedApps = {
	["kitty"] = true,
	["Terminal"] = true,
}

-- ── State ──────────────────────────────────────────────────────────────
local currentState = Modes.NORMAL
local currentAppName = ""
local stateMenu = hs.menubar.new()

-- Buffers for Vim counts and operators
local countBuffer = ""
local operatorBuffer = ""
local isGBuffer = false -- tracks if 'g' was pressed once

-- ── Helpers ────────────────────────────────────────────────────────────
local function dprint(...)
	if DEBUG then
		print(...)
	end
end

local function notify(msg)
	hs.alert.show(msg, 1.5)
end

local function setState(mode)
	local oldState = currentState
	currentState = mode
	if mode ~= Modes.NORMAL then
		countBuffer = ""
		operatorBuffer = ""
		isGBuffer = false
	end
	stateMenu:setTitle(icons[mode] or "[ ? ]")
	if oldState ~= mode then
		notify("Vim: " .. mode)
	end
end

local function getCount()
	local c = tonumber(countBuffer)
	return (c and c > 0) and c or 1
end

local function clearBuffers()
	countBuffer = ""
	operatorBuffer = ""
	isGBuffer = false
end

local function vimTableAppend(t1, t2)
	for i = 1, #t2 do
		t1[#t1 + 1] = t2[i]
	end
end

-- Helper to safely inject standard keystrokes without recursive eventtap triggering
local function inject(mods, key, count)
	count = count or 1
	local evts = {}
	for _ = 1, count do
		table.insert(evts, hs.eventtap.event.newKeyEvent(mods, key, true))
		table.insert(evts, hs.eventtap.event.newKeyEvent(mods, key, false))
	end
	return evts
end

-- Execute an operator (d, c, y) after a motion
local function executeOperator(op)
	local evts = {}
	if op == "d" then
		-- Cut
		vimTableAppend(evts, inject({ "cmd" }, "x"))
		setState(Modes.NORMAL)
	elseif op == "c" then
		-- Cut and enter insert
		vimTableAppend(evts, inject({ "cmd" }, "x"))
		setState(Modes.INSERT)
	elseif op == "y" then
		-- Copy, clear selection, back to normal
		vimTableAppend(evts, inject({ "cmd" }, "c"))
		vimTableAppend(evts, inject({}, "left"))
		setState(Modes.NORMAL)
	end
	clearBuffers()
	return evts
end

-- ── Key Interception ─────────────────────────────────────────────────
-- Optimization: Pre-fetch key map for O(1) matching checks
local k = hs.keycodes.map
local KC = {
	esc = k["escape"],
	h = k["h"],
	j = k["j"],
	k = k["k"],
	l = k["l"],
	w = k["w"],
	e = k["e"],
	b = k["b"],
	g = k["g"],
	G = k["g"], -- (G needs Shift check)
	d = k["d"],
	c = k["c"],
	y = k["y"],
	v = k["v"],
	x = k["x"],
	p = k["p"],
	u = k["u"],
	zero = k["0"],
	four = k["4"], -- $ is shift+4
}

local vimTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
	if currentAppName and excludedApps[currentAppName] then
		return false -- Allow app to handle naturally
	end

	local keyCode = event:getKeyCode()
	local flags = event:getFlags()
	local isShift = flags.shift
	local isCmd = flags.cmd or flags.alt or flags.ctrl -- Skip standard app macros

	-- 1. Pass through all Cmd/Ctrl/Option shortcuts (unless we are exclusively handling them)
	local isHandledCtrl = flags.ctrl and (keyCode == k["r"] or keyCode == k["d"] or keyCode == k["u"])
	if isCmd and keyCode ~= KC.esc and not isHandledCtrl then
		return false
	end

	-- 2. INSERT MODE
	if currentState == Modes.INSERT then
		if keyCode == KC.esc then
			setState(Modes.NORMAL)
			return true -- Suppress Escape
		end
		return false -- Pass everything else
	end

	-- 3. ESCAPE HANDLING (Normal / Visual)
	if keyCode == KC.esc then
		if currentState == Modes.VISUAL then
			setState(Modes.NORMAL)
			return true, inject({}, "left") -- Clear system selection
		else
			if countBuffer == "" and operatorBuffer == "" and not isGBuffer then
				return false -- PassThrough if buffer was empty, to allow system Esc
			else
				clearBuffers()
				return true
			end
		end
	end

	-- Identify character pressed
	local char = hs.keycodes.map[keyCode]
	if isShift and char then
		char = string.upper(char)
	end
	if keyCode == KC.four and isShift then
		char = "$"
	end
	if keyCode == KC.zero and not isShift then
		char = "0"
	end

	local count = getCount()
	if type(char) == "string" and char:lower() == "r" and flags.ctrl then
		if currentState == Modes.NORMAL then
			return true, inject({ "shift", "cmd" }, "z", count)
		end
		return false
	end

	-- 4. DIGITS (Count buffer)
	if type(char) == "string" and char:match("^[1-9]$") and operatorBuffer == "" and currentState == Modes.NORMAL then
		countBuffer = countBuffer .. char
		dprint("Count: ", countBuffer)
		return true
	end
	if char == "0" and countBuffer ~= "" and currentState == Modes.NORMAL then
		countBuffer = countBuffer .. "0"
		return true
	end

	local isOpPending = (operatorBuffer ~= "")

	-- Define motion mappings based on state
	local motionEvts = nil

	if flags.ctrl and type(char) == "string" then
		if char:lower() == "d" then
			if currentState == Modes.VISUAL or isOpPending then
				motionEvts = inject({ "shift" }, "pagedown", count)
			else
				motionEvts = inject({}, "pagedown", count)
			end
		elseif char:lower() == "u" then
			if currentState == Modes.VISUAL or isOpPending then
				motionEvts = inject({ "shift" }, "pageup", count)
			else
				motionEvts = inject({}, "pageup", count)
			end
		end
	elseif char == "h" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift" }, "left", count)
		else
			motionEvts = inject({}, "left", count)
		end
	elseif char == "j" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift" }, "down", count)
		else
			motionEvts = inject({}, "down", count)
		end
	elseif char == "k" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift" }, "up", count)
		else
			motionEvts = inject({}, "up", count)
		end
	elseif char == "l" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift" }, "right", count)
		else
			motionEvts = inject({}, "right", count)
		end
	elseif char == "w" or char == "e" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift", "alt" }, "right", count)
		else
			motionEvts = inject({ "alt" }, "right", count)
		end
	elseif char == "b" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift", "alt" }, "left", count)
		else
			motionEvts = inject({ "alt" }, "left", count)
		end
	elseif char == "0" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift", "cmd" }, "left")
		else
			motionEvts = inject({ "cmd" }, "left")
		end
	elseif char == "$" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift", "cmd" }, "right")
		else
			motionEvts = inject({ "cmd" }, "right")
		end
	elseif char == "g" then
		if currentState == Modes.NORMAL and not isGBuffer then
			isGBuffer = true
			return true
		elseif isGBuffer then
			if currentState == Modes.VISUAL or isOpPending then
				motionEvts = inject({ "shift", "cmd" }, "up")
			else
				motionEvts = inject({ "cmd" }, "up")
			end
			isGBuffer = false
		end
	elseif char == "G" then
		if currentState == Modes.VISUAL or isOpPending then
			motionEvts = inject({ "shift", "cmd" }, "down")
		else
			motionEvts = inject({ "cmd" }, "down")
		end
	end

	-- If a motion was triggered
	if motionEvts then
		if isOpPending then
			local finalEvts = motionEvts
			vimTableAppend(finalEvts, executeOperator(operatorBuffer))
			return true, finalEvts
		end
		clearBuffers()
		return true, motionEvts
	end

	isGBuffer = false -- Cancel 'g' wait if any other key pressed

	-- 5. OPERATIONS & ACTIONS
	if char == "s" and currentState == Modes.NORMAL then
		clickHints.Draw()
		return true
	end

	if char == "v" and currentState == Modes.NORMAL then
		setState(Modes.VISUAL)
		return true
	elseif char == "v" and currentState == Modes.VISUAL then
		setState(Modes.NORMAL)
		return true, inject({}, "left")
	end

	if char == "x" then
		if currentState == Modes.VISUAL then
			setState(Modes.NORMAL)
			return true, inject({ "cmd" }, "x")
		else
			return true, inject({}, "forwarddelete", count)
		end
	elseif char == "p" then
		if currentState == Modes.VISUAL then
			setState(Modes.NORMAL)
			return true, inject({ "cmd" }, "v")
		else
			local evts = inject({}, "right")
			vimTableAppend(evts, inject({ "cmd" }, "v"))
			return true, evts
		end
	elseif char == "u" then
		if currentState == Modes.VISUAL then
			setState(Modes.NORMAL)
		end
		return true, inject({ "cmd" }, "z", count)
	end

	-- Operators
	if char == "d" or char == "c" or char == "y" then
		if currentState == Modes.VISUAL then
			return true, executeOperator(char)
		elseif currentState == Modes.NORMAL then
			if operatorBuffer == char then -- e.g., 'dd', 'cc', 'yy' (Line action)
				local evts = inject({ "cmd" }, "left")
				vimTableAppend(evts, inject({ "shift", "cmd" }, "right"))
				if char == "d" then
					vimTableAppend(evts, inject({ "cmd" }, "x"))
					vimTableAppend(evts, inject({}, "delete"))
				elseif char == "c" then
					vimTableAppend(evts, inject({ "cmd" }, "x"))
					setState(Modes.INSERT)
				elseif char == "y" then
					vimTableAppend(evts, inject({ "cmd" }, "c"))
					vimTableAppend(evts, inject({}, "left"))
				end
				clearBuffers()
				return true, evts
			else
				operatorBuffer = char
				return true
			end
		end
	end

	if char == "i" then
		setState(Modes.INSERT)
		return true
	elseif char == "I" then
		setState(Modes.INSERT)
		return true, inject({ "cmd" }, "left")
	elseif char == "a" then
		setState(Modes.INSERT)
		return true, inject({}, "right")
	elseif char == "A" then
		setState(Modes.INSERT)
		return true, inject({ "cmd" }, "right")
	end

	-- Block all raw alphabet typing in Normal/Visual Mode
	if type(char) == "string" and char:match("^[A-Za-z]$") and not flags.ctrl then
		return true
	end

	return false
end)

-- ── Focus App Tracking ──────────────────────────────────────────────────
local appWatcher = hs.application.watcher.new(function(appName, eventType)
	if eventType == hs.application.watcher.activated then
		dprint("[VimInPlace] Focused: " .. appName)
		currentAppName = appName

		-- Default to NORMAL mode when switching apps
		if not excludedApps[appName] then
			setState(Modes.NORMAL)
		end
	end
end)

-- ── Main ────────────────────────────────────────────────────────────────
local frontmostApp = hs.application.frontmostApplication()
currentAppName = frontmostApp and frontmostApp:name() or ""
dprint("[VimInPlace] Initially Focused: " .. currentAppName)
setState(Modes.NORMAL)

vimTap:start()
appWatcher:start()

-- Expose explicitly to G to prevent garbage collection
_G.__vimInPlaceAppWatcher = appWatcher
_G.__vimInPlaceTap = vimTap
