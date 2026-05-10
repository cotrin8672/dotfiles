return {
	"cotrin8672/kyme.nvim",
	dependencies = {
		"folke/snacks.nvim",
		"akinsho/toggleterm.nvim",
	},
	opts = {
		sources = {
			{ "mise" },
		},
		picker = { "snacks" },
		runner = { "toggleterm" },
	},
	keys = {
		{
			"<leader>pt",
			function()
				require("kyme").pick_task()
			end,
			desc = "Pick task",
		},
		{
			"<leader>pe",
			function()
				require("kyme").pick_execution()
			end,
			desc = "Pick execution",
		},
	},
}
