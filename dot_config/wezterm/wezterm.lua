-- Pull in the wezterm API
local wezterm                        = require 'wezterm'
local wisteria                       = require 'wisteria'
local status                         = require 'status'
-- local session_manager                = require("wezterm-session-manager/session-manager")
-- This will hold the configuration.
local config                         = wezterm.config_builder()
config.automatically_reload_config   = true
config.font                          = wezterm.font_with_fallback({
    { family = "JetBrainsMono Nerd Font", weight = "Bold" },
    { family = "JetBrainsMonoNL Nerd Font", weight = "Bold" },
    { family = "Cica", weight = "Bold" },
    "Symbols Nerd Font Mono",
    "Nerd Font Symbols",
})
config.font_size                     = 10
config.use_ime                       = true
config.window_background_opacity     = 0.75
config.macos_window_background_blur  = 20
config.window_decorations            = "RESIZE"
config.default_cursor_style          = "BlinkingBlock"
config.cursor_blink_rate             = 500
config.cursor_blink_ease_in          = "Constant"
config.cursor_blink_ease_out         = "Constant"
config.use_ime                       = true
config.ime_preedit_rendering         = "Builtin"
config.show_close_tab_button_in_tabs = false
local mux                            = wezterm.mux
local ICONS                          = {
    wsl = wezterm.nerdfonts.cod_terminal_ubuntu,
    cmd = wezterm.nerdfonts.oct_terminal,
    fallback = wezterm.nerdfonts.fa_terminal,
}
local ICON_COLORS                    = {
    wsl = "#DF4E1C",
    cmd = "#CCCCCC",
    fallback = "#FFFFFF",
}
-- wezterm.on("save_session", function(window) session_manager.save_state(window) end)
-- wezterm.on("load_session", function(window) session_manager.load_state(window) end)
-- wezterm.on("restore_session", function(window) session_manager.restore_state(window) end)
config.default_prog                  = { 'nu' }

wezterm.on("gui-startup", function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

config.window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
    font_size = 14.0,
}
config.window_background_gradient = {
    colors = { wisteria.colors.background },
}
config.show_new_tab_button_in_tab_bar = false
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle
local ZOOM_ICON = wezterm.nerdfonts.md_magnify
local ZOOM_ICON_COLOR = "#F1C40F"
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local background = wisteria.tab_colors.inactive_bg
    local foreground = "#FFFFFF"
    local edge_background = "none"
    if tab.is_active then
        background = wisteria.tab_colors.active_bg
        foreground = "#FFFFFF"
    end
    local edge_foreground = background
    local domain_name = tab.active_pane.domain_name or "default"
    local title = domain_name:gsub("^WSL:", "")
    local icon
    local icon_color
    if tab.active_pane.is_zoomed then
        icon = ZOOM_ICON
        icon_color = ZOOM_ICON_COLOR
    else
        if string.match(domain_name, "^WSL") then
            icon = ICONS.wsl
            icon_color = ICON_COLORS.wsl
        elseif string.match(domain_name, "^local") then
            icon = ICONS.cmd
            icon_color = ICON_COLORS.cmd
        else
            icon = ICONS.fallback
            icon_color = ICON_COLORS.fallback
        end
    end
    return {
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_LEFT_ARROW },
        { Background = { Color = background } },
        { Foreground = { Color = icon_color } },
        { Text = icon .. "  " },
        { Background = { Color = background } },
        { Foreground = { Color = foreground } },
        { Text = title },
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_RIGHT_ARROW },
    }
end)
-- This is where you actually apply your config choices
-- For example, changing the color scheme:
-- config.color_scheme = "Nord"
config.leader = { key = "q", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
    { key = "h", mods = "CTRL",   action = wezterm.action.ActivatePaneDirection "Left" },
    { key = "l", mods = "CTRL",   action = wezterm.action.ActivatePaneDirection "Right" },
    { key = "k", mods = "CTRL",   action = wezterm.action.ActivatePaneDirection "Up" },
    { key = "j", mods = "CTRL",   action = wezterm.action.ActivatePaneDirection "Down" },
    { key = "r", mods = "LEADER", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" } },
    { key = "d", mods = "LEADER", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" } },
    {
        key = "T",
        mods = "CTRL|SHIFT",
        action = wezterm.action.ShowLauncher,
    },
    {
        key = 'c',
        mods = 'CTRL',
        action = wezterm.action_callback(function(window, pane)
            local selection_text = window:get_selection_text_for_pane(pane)
            local is_selection_active = string.len(selection_text) ~= 0
            if is_selection_active then
                window:perform_action(wezterm.action.CopyTo('ClipboardAndPrimarySelection'), pane)
            else
                window:perform_action(wezterm.action.SendKey { key = 'c', mods = 'CTRL' }, pane)
            end
        end),
    },
    {
        key = "V",
        mods = "CTRL",
        action = wezterm.action.PasteFrom("Clipboard"),
    },
    {
        key = 'Enter',
        mods = 'SHIFT',
        action = wezterm.action.SendString('\n')
    },
    {
        key = 'n',
        mods = 'SHIFT|CTRL',
        action = wezterm.action.ToggleFullScreen,
    },
    { key = "S", mods = "LEADER",     action = wezterm.action.ActivateKeyTable { name = 'resize_mode', one_shot = false } },
    { key = "x", mods = "LEADER",     action = wezterm.action.CloseCurrentPane { confirm = true } },
    { key = "+", mods = "CTRL",       action = wezterm.action.IncreaseFontSize },
    { key = "-", mods = "CTRL",       action = wezterm.action.DecreaseFontSize },
    { key = "0", mods = "CTRL",       action = wezterm.action.ResetFontSize },
    { key = "p", mods = "SHIFT|CTRL", action = wezterm.action.ActivateCommandPalette },
}

config.key_tables = {
    resize_mode = {
        { key = 'h',      action = wezterm.action.AdjustPaneSize { 'Left', 1 } },
        { key = 'j',      action = wezterm.action.AdjustPaneSize { 'Down', 1 } },
        { key = 'k',      action = wezterm.action.AdjustPaneSize { 'Up', 1 } },
        { key = 'l',      action = wezterm.action.AdjustPaneSize { 'Right', 1 } },
        { key = 'Escape', action = 'PopKeyTable' },
        { key = 'Enter',  action = 'PopKeyTable' },
    }
}
config.inactive_pane_hsb = {
    saturation = 0.5,
    brightness = 0.2,
}
wisteria.colors.tab_bar = {
    background = "none",
}
config.colors = wisteria.colors

wezterm.on('update-right-status', function(window, pane)
    local leader = ''
    if window:leader_is_active() then
        leader = 'LEADER'
    end
    window:set_right_status(leader)
end)

status.setup()
-- and finally, return the configuration to wezterm
return config
