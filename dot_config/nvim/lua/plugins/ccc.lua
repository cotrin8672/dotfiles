return {
	"uga-rosa/ccc.nvim",
	opts = {
		highlighter = {
			auto_enable = false,
			lsp = true,
		},
	},
	keys = {
		{
			"<leader>pc",
			"<cmd>CccPick<cr>",
			mode = "n",
			desc = "Color picker",
		},
	},
}
