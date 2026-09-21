-- Pull in the wezterm API
local wezterm = require("wezterm")
local tabline = require("tabline")
local cyberdream = require("cyberdream")
local config = wezterm.config_builder()
local blur_off_window_background_opacity = 0.7
config.automatically_reload_config = true
config.font = wezterm.font_with_fallback({
	{ family = "UDEV Gothic 35NFLG" },
})
config.font_size = 11
config.adjust_window_size_when_changing_font_size = false
config.use_ime = true
config.window_background_opacity = 0
config.win32_system_backdrop = "Acrylic"
config.front_end = "OpenGL"
config.webgpu_power_preference = "HighPerformance"
config.window_decorations = "RESIZE"
config.default_cursor_style = "BlinkingBlock"
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"
config.use_ime = true
config.ime_preedit_rendering = "Builtin"
config.show_close_tab_button_in_tabs = false
config.custom_block_glyphs = true
config.anti_alias_custom_block_glyphs = true
-- config.color_scheme = "Everforest Dark Hard (Gogh)"
config.colors = cyberdream.colors

local mux = wezterm.mux
local BLUR_ON_OPACITY = config.window_background_opacity
local BLUR_ON_BACKDROP = config.win32_system_backdrop
local BLUR_OFF_OPACITY = blur_off_window_background_opacity
local BLUR_OFF_BACKDROP = "Disable"

local function is_blur_enabled(window)
	local overrides = window:get_config_overrides() or {}
	local backdrop = overrides.win32_system_backdrop

	if backdrop == nil then
		backdrop = BLUR_ON_BACKDROP
	end

	return backdrop == BLUR_ON_BACKDROP
end

local function toggle_blur(window)
	local overrides = window:get_config_overrides() or {}
	local enable_blur = not is_blur_enabled(window)

	overrides.window_background_opacity = enable_blur and BLUR_ON_OPACITY or BLUR_OFF_OPACITY
	overrides.win32_system_backdrop = enable_blur and BLUR_ON_BACKDROP or BLUR_OFF_BACKDROP

	window:set_config_overrides(overrides)
	window:toast_notification("WezTerm", enable_blur and "Blur enabled" or "Blur disabled", nil, 1500)
end

config.default_prog = { "nu" }

wezterm.on("gui-startup", function(cmd)
	local _, _, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

config.window_frame = {
	inactive_titlebar_bg = "none",
	active_titlebar_bg = "none",
	font_size = 14.0,
}
config.window_background_gradient = {
	colors = { cyberdream.colors.background },
}

config.show_new_tab_button_in_tab_bar = false
-- This is where you actually apply your config choices
-- For example, changing the color scheme:
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{ key = "h", mods = "LEADER", action = wezterm.action.SplitPane({ direction = "Left" }) },
	{ key = "j", mods = "LEADER", action = wezterm.action.SplitPane({ direction = "Down" }) },
	{ key = "k", mods = "LEADER", action = wezterm.action.SplitPane({ direction = "Up" }) },
	{ key = "l", mods = "LEADER", action = wezterm.action.SplitPane({ direction = "Right" }) },
	{
		key = "T",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ShowLauncher,
	},
	{
		key = "B",
		mods = "CTRL|SHIFT",
		action = wezterm.action_callback(function(window, _)
			toggle_blur(window)
		end),
	},
	{
		key = "c",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane)
			local selection_text = window:get_selection_text_for_pane(pane)
			local is_selection_active = string.len(selection_text) ~= 0
			if is_selection_active then
				window:perform_action(wezterm.action.CopyTo("ClipboardAndPrimarySelection"), pane)
			else
				window:perform_action(wezterm.action.SendKey({ key = "c", mods = "CTRL" }), pane)
			end
		end),
	},
	{
		key = "V",
		mods = "CTRL",
		action = wezterm.action.PasteFrom("Clipboard"),
	},
	{
		key = "Enter",
		mods = "SHIFT",
		action = wezterm.action.SendString("\n"),
	},
	{
		key = "n",
		mods = "SHIFT|CTRL",
		action = wezterm.action.ToggleFullScreen,
	},
	{
		key = "s",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable({ name = "resize_mode", one_shot = false }),
	},
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	{ key = "+", mods = "CTRL", action = wezterm.action.IncreaseFontSize },
	{ key = "-", mods = "CTRL", action = wezterm.action.DecreaseFontSize },
	{ key = "0", mods = "CTRL", action = wezterm.action.ResetFontSize },
	{ key = "p", mods = "SHIFT|CTRL", action = wezterm.action.ActivateCommandPalette },
	{ key = "h", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Right") },
}

config.key_tables = {
	resize_mode = {
		{ key = "h", action = wezterm.action.AdjustPaneSize({ "Left", 1 }) },
		{ key = "j", action = wezterm.action.AdjustPaneSize({ "Down", 1 }) },
		{ key = "k", action = wezterm.action.AdjustPaneSize({ "Up", 1 }) },
		{ key = "l", action = wezterm.action.AdjustPaneSize({ "Right", 1 }) },
		{ key = "Escape", action = "PopKeyTable" },
		{ key = "Enter", action = "PopKeyTable" },
	},
}
config.colors.tab_bar = {
	background = "none",
}

-- Do not paste the primary selection on a middle-click.
config.mouse_bindings = {
	{
		event = { Down = { streak = 1, button = "Middle" } },
		mods = "NONE",
		action = wezterm.action.DisableDefaultAssignment,
	},
}

tabline.setup(config)

return config
