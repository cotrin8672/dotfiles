return {
	"cotrin8672/kyme.nvim",
	lazy = true,
	dependencies = {
		"folke/snacks.nvim",
	},
	opts = function()
		local kyme = require("kyme")

		return {
			sources = {
				kyme.mise(),
			},
			runner = kyme.system(),
		}
	end,
	keys = {
		{
			"<leader>pt",
			function()
				require("config.kyme.picker").tasks()
			end,
			desc = "Pick task",
		},
		{
			"<leader>pe",
			function()
				require("config.kyme.picker").executions()
			end,
			desc = "Pick execution",
		},
	},
}
