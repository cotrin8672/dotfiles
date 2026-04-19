return {
	"folke/flash.nvim",
	event = "VeryLazy",
	opts = {
		modes = {
			char = { enabled = true },
			search = { enabled = false },
			treesitter = { enabled = false },
		},
	},
	keys = {
		{
			"<CR>",
			mode = { "n", "x", "o" },
			function()
				require("flash").jump({
					label = { before = true, after = false },
				})
			end,
			desc = "Flash",
		},
		{
			"<leader>r",
			mode = { "n", "x", "o" },
			function()
				require("flash").remote()
			end,
			desc = "Remote Flash",
		},
	},
}
