return {
	"olimorris/codecompanion.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"lalitmee/codecompanion-spinners.nvim",
	},
	opts = {
		opts = {
			language = "Japanese",
		},
		interactions = {
			chat = {
				adapter = {
					name = "copilot",
					model = "raptor-mini",
				},
			},
			inline = {
				adapter = {
					name = "copilot",
					model = "raptor-mini",
				},
			},
			cmd = {
				adapter = {
					name = "copilot",
					model = "raptor-mini",
				},
			},
			shared = {
				keymaps = {
					always_accept = {
						callback = "keymaps.always_accept",
						modes = { n = "gdA" },
						description = "Accept CodeCompanion inline change",
					},
					accept_change = {
						callback = "keymaps.accept_change",
						modes = { n = "gda" },
						description = "Accept CodeCompanion inline change",
					},
					reject_change = {
						callback = "keymaps.reject_change",
						modes = { n = "gdr" },
						description = "Reject CodeCompanion inline change",
					},
				},
			},
		},
		extensions = {
			spinner = {
				opts = { style = "fidget" },
			},
		},
	},
	keys = {
		{
			"<leader>ai",
			"<cmd>CodeCompanion<CR>",
			mode = "n",
			desc = "CodeCompanion inline: prompt",
			noremap = true,
			silent = true,
		},
		{
			"<leader>ai",
			"<cmd>CodeCompanion<CR>",
			mode = "v",
			desc = "CodeCompanion inline: prompt",
			noremap = true,
			silent = true,
		},
	},
}
