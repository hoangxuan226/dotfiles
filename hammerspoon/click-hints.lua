-- click-hints.lua
-- This module highlights clickable elements on the focused window and allows keyboard-driven clicking.

-- ── Config ─────────────────────────────────────────────────────────────
local DEBUG = false

-- Maximum depth for UI element traversal
local MAX_DEPTH = 100

-- Minimum size to be considered clickable
local MIN_WIDTH = 2
local MIN_HEIGHT = 2

-- Size of the number badge
local BADGE_W = 24
local BADGE_H = 14

-- Keycodes for relevant keys (ESC, Return/Enter, Delete)
local KEYS = {
	ESC = 53,
	RETURN = 36,
	SPACE = 49,
	DELETE = 51,
}

-- Elements supporting any of these actions will be considered clickable
local ACTIONS = {
	AXPress = true,
	AXOpen = true,
	AXPick = false,
	AXConfirm = false,
}

-- ── State ──────────────────────────────────────────────────────────────
local overlays = {}
local clickables = {}
local tap = nil
local typedNumber = ""
local hintMenu = nil
local hiddenMousePos = nil

-- ── Helpers ────────────────────────────────────────────────────────────
-- Print debug messages only if DEBUG is enabled
local function dprint(...)
	if DEBUG then
		print(...)
	end
end

-- Show a temporary on-screen notification
local function notify(msg)
	hs.alert.show(msg, 1.5)
end

-- Clear all rendered highlights and reset state variables
local function clearOverlays()
	for _, c in ipairs(overlays) do
		c:delete()
	end
	overlays = {}
end

-- Exit the clickable mode, removing event listeners and graphical overlays
local function exitMode()
	if tap then
		tap:stop()
		tap = nil
	end
	if hintMenu then
		hintMenu:removeFromMenuBar()
		hintMenu = nil
	end
	clearOverlays()
	typedNumber = ""
end

local function updateMenu()
	if not hintMenu then
		hintMenu = hs.menubar.new()
	end
	local displayStr = typedNumber == "" and "..." or typedNumber
	local styled = hs.styledtext.new("[ " .. displayStr .. " ]", {
		color = { red = 0.9, green = 0.6, blue = 0.2 },
	})
	hintMenu:setTitle(styled)
end

-- Print details about a specific accessibility element
local function printElementDebugInfo(el, frame, index, prefix)
	print("\n--- " .. prefix .. " ELEMENT " .. index .. " ---")
	print("Role: " .. tostring(el:attributeValue("AXRole")))
	print("Subrole: " .. tostring(el:attributeValue("AXSubrole")))
	print("Title: " .. tostring(el:attributeValue("AXTitle")))
	print("Description: " .. tostring(el:attributeValue("AXDescription")))
	print("Frame: " .. hs.inspect(frame))
	print("Actions: " .. hs.inspect(el:actionNames()))
	print("------------------------\n")
end

-- Check if an element supports any of our configured clickable actions
local function isElementClickable(actions)
	if not actions then
		return false
	end
	for _, action in ipairs(actions) do
		if ACTIONS[action] then
			return true
		end
	end
	return false
end

-- DFS traversal to gather all clickable elements inside a window
local function findClickables(rootElement)
	clickables = {}
	local stack = { { element = rootElement, depth = 0 } }

	while #stack > 0 do
		local current = table.remove(stack)
		local el = current.element
		local depth = current.depth

		if depth <= MAX_DEPTH then
			local actions = el:actionNames()

			if isElementClickable(actions) then
				local frame = el:attributeValue("AXFrame")
				if frame and frame.w > MIN_WIDTH and frame.h > MIN_HEIGHT then
					table.insert(clickables, { frame = frame, element = el })
				end
			end

			-- Insert children in reverse to maintain left-to-right visual mapping when popping
			local children = el:attributeValue("AXChildren")
			if children and type(children) == "table" and #children > 0 then
				for i = #children, 1, -1 do
					table.insert(stack, { element = children[i], depth = depth + 1 })
				end
			end
		end
	end

	print("[findClickables] Found clickables:", #clickables)
end

-- Draw numerical badges and highlight borders over found clickable elements
local function drawHints(win)
	local sFrame = win:screen():fullFrame()
	local uFrame = win:screen():frame() -- usable frame excluding menubar/notch
	local safeTop = uFrame.y - sFrame.y

	local canvas = hs.canvas.new(sFrame)
	canvas:level(hs.canvas.windowLevels.overlay)

	local elements = {}
	local badgeElements = {}

	for i, item in ipairs(clickables) do
		local frame = item.frame
		local relX = frame.x - sFrame.x
		local relY = frame.y - sFrame.y

		-- 1. Main highlight box
		table.insert(elements, {
			type = "rectangle",
			action = "strokeAndFill",
			strokeColor = { red = 1, green = 0.3, blue = 0, alpha = 0.8 },
			strokeWidth = 2,
			fillColor = { red = 1, green = 0.3, blue = 0, alpha = 0.1 },
			roundedRectRadii = { xRadius = 3, yRadius = 3 },
			frame = { x = relX, y = relY, w = frame.w, h = frame.h },
		})

		-- 2. Calculate badge position (aligned to top-left of the box without gap)
		local badgeX = relX
		local badgeY = relY - BADGE_H

		-- Auto-correction if badge is pushed into the notch/menubar or above the screen edge
		if badgeY < safeTop then
			badgeY = math.max(relY, safeTop)
			badgeX = relX
		end

		-- 3. Badge background (reduced alpha to 0.5)
		table.insert(badgeElements, {
			type = "rectangle",
			action = "fill",
			fillColor = { red = 0.1, green = 0.1, blue = 0.1, alpha = 0.5 },
			roundedRectRadii = { xRadius = 2, yRadius = 2 },
			frame = { x = badgeX, y = badgeY, w = BADGE_W, h = BADGE_H },
		})

		-- 4. Badge text
		table.insert(badgeElements, {
			type = "text",
			text = tostring(i),
			textColor = { white = 1, alpha = 0.9 },
			textSize = 10,
			textAlignment = "center",
			frame = { x = badgeX, y = badgeY - 0.5, w = BADGE_W, h = BADGE_H },
		})

		-- Store badge frame conditionally for debug clicking
		if DEBUG then
			item.badgeFrame = {
				x = badgeX + sFrame.x,
				y = badgeY + sFrame.y,
				w = BADGE_W,
				h = BADGE_H,
			}
		end
	end

	-- Append all highlight boxes first, then badge elements on top to preserve Z-index
	for _, b in ipairs(badgeElements) do
		table.insert(elements, b)
	end

	if #elements > 0 then
		canvas:appendElements(elements)
		canvas:show()
		table.insert(overlays, canvas)
	end

	-- Hide mouse on the right edge (middle Y) to avoid notch/hot corners and keep hints visible
	hiddenMousePos = { x = sFrame.x + sFrame.w - 1, y = sFrame.y + (sFrame.h / 2) }
	hs.mouse.absolutePosition(hiddenMousePos)

	print("[drawHints] Drew overlay canvas with", #elements, "elements")
end

-- Check if mouse click coordinates fall inside an element's badge
local function handleDebugMouseClick(pt)
	for i, item in ipairs(clickables) do
		local bf = item.badgeFrame
		if bf and pt.x >= bf.x and pt.x <= (bf.x + bf.w) and pt.y >= bf.y and pt.y <= (bf.y + bf.h) then
			printElementDebugInfo(item.element, item.frame, i, "DEBUG")
			return true -- Consume the click
		end
	end
	return false -- Click was elsewhere
end

-- Start capturing keyboard input (and optionally mouse) to interact with highlights
local function startInputMode()
	local eventsToListen = { hs.eventtap.event.types.keyDown }
	updateMenu()

	-- Setup mouse click interception if in debug mode
	if DEBUG then
		table.insert(eventsToListen, hs.eventtap.event.types.leftMouseDown)
	end

	tap = hs.eventtap.new(eventsToListen, function(e)
		local eventType = e:getType()

		-- Handle debug clicking on badges if DEBUG is true
		if DEBUG and eventType == hs.eventtap.event.types.leftMouseDown then
			local pt = e:location()
			if handleDebugMouseClick(pt) then
				return true
			end

			-- If click missed badges, cleanly exit and allow native OS handling
			exitMode()
			dprint("[startInputMode] Canceled clickable mode via mouse click")
			return false
		end

		local keyCode = e:getKeyCode()
		local char = e:getCharacters(true)

		if keyCode == KEYS.ESC then
			exitMode()
			dprint("[startInputMode] Canceled clickable mode")
			return true
		elseif keyCode == KEYS.RETURN or keyCode == KEYS.SPACE then
			local num = tonumber(typedNumber)
			exitMode()

			if num and clickables[num] then
				local frame = clickables[num].frame
				local centerPt = { x = frame.x + (frame.w / 2), y = frame.y + (frame.h / 2) }
				hs.eventtap.leftClick(centerPt)
				dprint(
					string.format("[startInputMode] Clicked element %d at (%.1f, %.1f)", num, centerPt.x, centerPt.y)
				)

				-- Snap the cursor back to the hidden edge after the native click is registered
				hs.mouse.absolutePosition(hiddenMousePos)
			else
				dprint("[startInputMode] Invalid number or element not found")
			end
			return true
		elseif keyCode == KEYS.DELETE then
			typedNumber = string.sub(typedNumber, 1, -2)
			updateMenu()
			dprint("[startInputMode] Typed: " .. typedNumber)
			return true
		elseif char and char:match("%d") then
			typedNumber = typedNumber .. char
			updateMenu()
			dprint("[startInputMode] Typed: " .. typedNumber)
			return true
		end

		return true -- Block unaccounted keystrokes while mode is active
	end)
	tap:start()
end

-- ── Exported Functions ─────────────────────────────────────────────────
-- Main trigger to find clickables and show hints
local function Draw()
	exitMode() -- clean up previous state if any

	local win = hs.window.focusedWindow()
	if not win then
		dprint("[Draw] No focused window found")
		notify("No focused window found")
		return
	end

	local axWin = hs.axuielement.windowElement(win)
	if not axWin then
		dprint("[Draw] No accessibility window element found")
		notify("No window element found")
		return
	end

	findClickables(axWin)
	drawHints(win)
	startInputMode()
end

-- Trigger to exit clickable mode
local Eraser = function()
	exitMode()
	dprint("[Eraser] Canceled clickable mode.")
end

-- API to debug print element info manually via Hammerspoon Console
local function DebugElement(num)
	if not clickables or #clickables == 0 then
		print("[DebugElement] No clickables found.")
		return
	end

	local item = clickables[num]
	if not item then
		print("[DebugElement] Element " .. tostring(num) .. " not found.")
		return
	end

	printElementDebugInfo(item.element, item.frame, num, "MANUAL DEBUG")
end

return {
	Draw = Draw,
	Eraser = Eraser,
	DebugElement = DebugElement,
}
