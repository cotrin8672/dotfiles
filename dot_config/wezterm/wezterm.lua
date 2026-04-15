-- Pull in the wezterm API
local wezterm = require("wezterm")
local tabline = require("tabline")
local config = wezterm.config_builder()
local blur_off_window_background_opacity = 0.7
config.automatically_reload_config = true
config.font = wezterm.font("UDEV Gothic 35NFLG")
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
config.color_scheme = "Everforest Dark Hard (Gogh)"

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
local scheme = wezterm.color.get_builtin_schemes()[config.color_scheme]
config.window_background_gradient = {
	colors = { scheme.background },
}

local direction_keys = {
	h = "Left",
	j = "Down",
	k = "Up",
	l = "Right",
}

local function basename(path)
	if not path then
		return nil
	end
	return string.gsub(path, "(.*[/\\])(.*)", "%2"):lower()
end

local function is_vim(pane)
	local user_vars = pane:get_user_vars()
	if user_vars and user_vars.IS_NVIM == "true" then
		return true
	end

	local process_name = basename(pane:get_foreground_process_name())
	if process_name == "nvim" or process_name == "nvim.exe" or process_name == "vim" or process_name == "vim.exe" then
		return true
	end

	local ok, process_info = pcall(function()
		return pane:get_foreground_process_info()
	end)
	if ok and process_info and process_info.executable then
		local executable = basename(process_info.executable)
		if executable == "nvim" or executable == "nvim.exe" or executable == "vim" or executable == "vim.exe" then
			return true
		end
	end

	local title = pane:get_title()
	if title and title:lower():match("n?vim") then
		return true
	end

	return false
end

local function smart_nav(key)
	return wezterm.action_callback(function(window, pane)
		if is_vim(pane) or #window:active_tab():panes() == 1 then
			window:perform_action(wezterm.action.SendKey({ key = key, mods = "CTRL" }), pane)
			return
		end

		window:perform_action(wezterm.action.ActivatePaneDirection(direction_keys[key]), pane)
	end)
end

config.show_new_tab_button_in_tab_bar = false
-- This is where you actually apply your config choices
-- For example, changing the color scheme:
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{ key = "r", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
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
		key = "S",
		mods = "LEADER",
		action = wezterm.action.ActivateKeyTable({ name = "resize_mode", one_shot = false }),
	},
	{ key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = true }) },
	{ key = "+", mods = "CTRL", action = wezterm.action.IncreaseFontSize },
	{ key = "-", mods = "CTRL", action = wezterm.action.DecreaseFontSize },
	{ key = "0", mods = "CTRL", action = wezterm.action.ResetFontSize },
	{ key = "p", mods = "SHIFT|CTRL", action = wezterm.action.ActivateCommandPalette },
	{ key = "h", mods = "CTRL", action = smart_nav("h") },
	{ key = "j", mods = "CTRL", action = smart_nav("j") },
	{ key = "k", mods = "CTRL", action = smart_nav("k") },
	{ key = "l", mods = "CTRL", action = smart_nav("l") },
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
config.colors = {
	tab_bar = {
		background = "none",
	},
}

tabline.setup(config)

return config
