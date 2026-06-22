return {
	"gbprod/yanky.nvim",
	dependencies = {
		"folke/snacks.nvim",
		"y3owk1n/undo-glow.nvim",
	},
	opts = {
		ring = {
			sync_with_numbered_registers = false,
		},
		system_clipboard = {
			sync_with_ring = false,
		},
		highlight = {
			on_put = false,
			on_yank = false,
		},
		preserve_cursor_position = {
			enabled = true,
		},
		textobj = {
			enabled = true,
		},
	},
	keys = {
		{
			"<leader>fy",
			function()
				Snacks.picker.yanky()
			end,
			mode = { "n", "x" },
			desc = "Yank history",
		},
		{
			"<C-p>",
			"<Plug>(YankyPreviousEntry)",
			mode = "n",
			desc = "Previous yank entry",
		},
		{
			"<C-n>",
			"<Plug>(YankyNextEntry)",
			mode = "n",
			desc = "Next yank entry",
		},
		{
			"y",
			"<Plug>(YankyYank)",
			mode = { "n", "x" },
			desc = "Yank text",
		},
		{
			"p",
			function()
				return require("undo-glow").yanky_put("YankyPutAfter")
			end,
			mode = { "n", "x" },
			desc = "Put yanked text after cursor",
			expr = true,
		},
		{
			"P",
			function()
				return require("undo-glow").yanky_put("YankyPutBefore")
			end,
			mode = { "n", "x" },
			desc = "Put yanked text before cursor",
			expr = true,
		},
		{
			"iy",
			function()
				require("yanky.textobj").last_put()
			end,
			mode = { "o", "x" },
			desc = "Last put text",
		},
	},
}
