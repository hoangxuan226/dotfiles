local wezterm = require("wezterm")
local config = wezterm.config_builder()
local act = wezterm.action

-- wezterm.on("gui-startup", function(cmd)
-- 	local tab, pane, window = wezterm.mux.spawn_window(cmd or {})
-- 	-- window:gui_window():toggle_fullscreen()
-- 	window:gui_window():maximize()
-- end)

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

-- Font setting
config.font = wezterm.font_with_fallback({
	--"Hack Nerd Font",
	{ family = "Inconsolata Nerd Font", weight = "Bold" },
})
config.font_size = 16
config.line_height = 1.1

-- Colors
config.colors = {
	cursor_bg = "white",
}

-- Appearance
config.underline_position = -3
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.window_background_opacity = 0.85
config.window_padding = {
	left = 5,
	right = 5,
	top = 0,
	bottom = 0,
}

-- Miscellaneous settings
config.max_fps = 120
config.prefer_egl = true

-- Compatibility settings (fcitx wsl)
config.use_ime = true
config.xim_im_name = "fcitx"
config.enable_wayland = false

return config
