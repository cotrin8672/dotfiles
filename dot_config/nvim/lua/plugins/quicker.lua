return {
	"stevearc/quicker.nvim",
	ft = "qf",
	keys = {
		{
			"<leader>q",
			function()
				require("quicker").toggle()
			end,
			desc = "Toggle quickfix",
		},
		{
			"<leader>l",
			function()
				require("quicker").toggle({ loclist = true })
			end,
			desc = "Toggle loclist",
		},
	},
	opts = {
		opts = {
			number = true,
			relativenumber = false,
		},
	},
}
