local wezterm = require("wezterm")
local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")

local M = {}
local process_icon_overrides = {
	[".*codex"] = { wezterm.nerdfonts.md_robot, color = { fg = "#7dcfff" } },
	[".*claude"] = { wezterm.nerdfonts.md_brain, color = { fg = "#e0af68" } },
	[".*nvim"] = { wezterm.nerdfonts.custom_neovim, color = { fg = "#9ece6a" } },
}

function M.setup(config)
	config.tab_bar_at_bottom = true

	tabline.setup({
		options = {
			theme = config.color_scheme,
			section_separators = {
				left = wezterm.nerdfonts.ple_upper_left_triangle,
				right = wezterm.nerdfonts.ple_lower_right_triangle,
			},
			component_separators = {
				left = wezterm.nerdfonts.ple_upper_left_triangle,
				right = wezterm.nerdfonts.ple_lower_right_triangle,
			},
			tab_separators = {
				left = wezterm.nerdfonts.ple_upper_left_triangle,
				right = wezterm.nerdfonts.ple_lower_right_triangle,
			},
		},
		sections = {
			tabline_x = { "ram" },
			tabline_y = { "cpu" },
			tab_active = {
				"index",
				{
					"process",
					icons_only = true,
					padding = { left = 1, right = 0 },
					process_to_icon = process_icon_overrides,
				},
				{ "cwd", padding = 1 },
			},
			tab_inactive = {
				"index",
				{
					"process",
					icons_only = true,
					padding = { left = 1, right = 0 },
					process_to_icon = process_icon_overrides,
				},
				{ "cwd", padding = 1 },
			},
		},
	})

	tabline.apply_to_config(config)
end

return M
