local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

local function is_wsl()
	-- Check /proc/version for WSL indicators
	local f = io.open("/proc/version", "r")
	if f then
		local content = f:read("*all")
		f:close()
		-- Check for both "Microsoft" and "microsoft" (case-insensitive)
		if content:lower():find("microsoft") or content:lower():find("wsl") then
			return true
		end
	end

	-- Fallback: check if /proc/sys/fs/binfmt_misc/WSLInterop exists
	local wsl_interop = io.open("/proc/sys/fs/binfmt_misc/WSLInterop", "r")
	if wsl_interop then
		wsl_interop:close()
		return true
	end

	return false
end

-- On GUI startup, setup size and position
wezterm.on("gui-startup", function(cmd)
	local _, _, window = wezterm.mux.spawn_window(cmd or {})
	local screens = wezterm.gui.screens()
	local active_screen = screens.active

	if active_screen then
		wezterm.log_info("Screen: " .. active_screen.width .. "x" .. active_screen.height)

		-- Define padding in pixels
		local padding = 40

		-- Calculate window dimensions with padding
		local window_width = active_screen.width - (padding * 2)
		local window_height = active_screen.height - (padding * 2)

		wezterm.log_info("Built-in WSL detection: " .. tostring(wezterm.running_under_wsl()))
		wezterm.log_info("Custom WSL detection: " .. tostring(is_wsl()))

		if wezterm.running_under_wsl() or is_wsl() then
			-- set_position does not work properly in WSL
			-- so we maximize the window instead
			window:gui_window():maximize()
		else
			window:gui_window():set_position(padding, padding)
			wezterm.log_info(
				"Window: " .. window_width .. "x" .. window_height .. " at (" .. padding .. "," .. padding .. ")"
			)
		end

		-- set_inner_size and window auto-centers itself in case maximize
		window:gui_window():set_inner_size(window_width, window_height)
	else
		wezterm.log_info("No active screen detected")
	end
end)

config.keys = {
	-- paste from the clipboard
	{ key = "v", mods = "CTRL", action = act.PasteFrom("Clipboard") },

	-- paste from the primary selection
	{ key = "v", mods = "CTRL", action = act.PasteFrom("PrimarySelection") },
}

-- GPU Acceleration
-- for _, gpu in ipairs(wezterm.gui.enumerate_gpus()) do
-- 	if gpu.backend == "Vulkan" and gpu.device_type == "DiscreteGpu" then
-- 		config.webgpu_preferred_adapter = gpu
-- 		config.front_end = "WebGpu"
-- 		break
-- 	end
-- end

-- Font setting (get available fonts: wezterm ls-fonts --list-system)
config.font = wezterm.font_with_fallback({
	--"Hack Nerd Font",
	-- "Inconsolata Nerd Font",
	-- "JetBrainsMono Nerd Font",
	"JetBrainsMonoNL Nerd Font", -- the "NL" stands for **No Ligatures**, won't auto-convert `>=` into a single glyph
	-- { family = "Inconsolata Nerd Font", weight = "Bold" },
})
-- config.font_size = 14
-- config.line_height = 1.1

-- Colors
-- local os_theme = wezterm.gui.get_appearance()
-- if os_theme:find("Dark") then
-- 	config.color_scheme = "Catppuccin Mocha"
-- else
-- 	config.color_scheme = "Catppuccin Latte"
-- end
config.color_scheme = "Catppuccin Mocha"
config.colors = {
	cursor_bg = "white",
}

-- Appearance
config.underline_position = -3
config.window_decorations = "NONE"
config.hide_tab_bar_if_only_one_tab = true
config.window_background_opacity = 0.9
-- config.window_padding = {
-- 	left = 5,
-- 	right = 5,
-- 	top = 0,
-- 	bottom = 0,
-- }

-- Miscellaneous settings
config.max_fps = 120
config.prefer_egl = true

-- Compatibility settings (fcitx wsl)
config.use_ime = true
config.xim_im_name = "fcitx"
config.enable_wayland = false

return config
