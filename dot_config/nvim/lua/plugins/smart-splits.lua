return {
	"mrjones2014/smart-splits.nvim",
	lazy = false,
	opts = {
		at_edge = "stop",
		wezterm_cli_path = "C:\\Users\\gummy\\scoop\\shims\\wezterm.exe",
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
