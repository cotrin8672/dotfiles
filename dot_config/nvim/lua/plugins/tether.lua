return {
	"cotrin8672/tether.nvim",
	dependencies = {
		"folke/snacks.nvim",
	},
	opts = {
		ui = {
			picker = "snacks",
		},
	},
	cmd = {
		"TetherOpen",
		"TetherAccept",
		"TetherReject",
	},
	keys = {
		{
			"gl",
			function()
				return require("tether").operator()
			end,
			mode = "n",
			expr = true,
			desc = "Tether AI operator",
		},
		{
			"gl",
			function()
				require("tether").visual()
			end,
			mode = "x",
			desc = "Tether AI selection",
		},
		{
			"<leader>ao",
			function()
				require("tether").open()
			end,
			desc = "Open tether task",
		},
		{
			"<leader>aa",
			function()
				require("tether").accept()
			end,
			desc = "Accept tether proposal",
		},
		{
			"<leader>ax",
			function()
				require("tether").reject()
			end,
			desc = "Reject tether proposal",
		},
	},
}
