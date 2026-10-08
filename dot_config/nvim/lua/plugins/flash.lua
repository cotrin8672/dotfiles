return {
	"folke/flash.nvim",
	opts = {
		modes = {
			char = { enabled = true },
			search = { enabled = false },
			treesitter = { enabled = false },
		},
	},
	keys = {
		{ "f", mode = { "n", "x", "o" } },
		{ "F", mode = { "n", "x", "o" } },
		{ "t", mode = { "n", "x", "o" } },
		{ "T", mode = { "n", "x", "o" } },
		{
			"<leader>j",
			mode = { "n", "x", "o" },
			function()
				require("lazy").load({ plugins = { "vim-kensaku" } })
				require("flash").jump({
					label = { before = true, after = false },
					search = {
						mode = function(input)
							return vim.fn["kensaku#query"](input, {
								rxop = vim.g["kensaku#rxop#vim"],
							})
						end,
					},
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
