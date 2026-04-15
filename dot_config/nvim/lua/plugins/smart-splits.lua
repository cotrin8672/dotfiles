local wezterm_cli_path = (function()
	local candidates = vim.env.WSL_DISTRO_NAME and { "wezterm.exe", "wezterm" } or { "wezterm", "wezterm.exe" }
	for _, command in ipairs(candidates) do
		if vim.fn.executable(command) == 1 then
			return command
		end
	end
	return candidates[1]
end)()

return {
	"mrjones2014/smart-splits.nvim",
	lazy = false,
	opts = {
		at_edge = "stop",
		multiplexer_integration = "wezterm",
		wezterm_cli_path = wezterm_cli_path,
	},
	keys = {
		{
			"<C-h>",
			function()
				require("smart-splits").move_cursor_left()
			end,
			mode = "n",
			desc = "Move to left split",
			silent = true,
		},
		{
			"<C-j>",
			function()
				require("smart-splits").move_cursor_down()
			end,
			mode = "n",
			desc = "Move to lower split",
			silent = true,
		},
		{
			"<C-k>",
			function()
				require("smart-splits").move_cursor_up()
			end,
			mode = "n",
			desc = "Move to upper split",
			silent = true,
		},
		{
			"<C-l>",
			function()
				require("smart-splits").move_cursor_right()
			end,
			mode = "n",
			desc = "Move to right split",
			silent = true,
		},
	},
}
