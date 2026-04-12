return {
	"nvimdev/lspsaga.nvim",
	event = "LspAttach",
	keys = {
		{
			"<leader>ca",
			"<cmd>Lspsaga code_action<cr>",
			mode = "n",
			desc = "LSP Code Action",
		},
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		lightbulb = {
			enable = false,
		},
	},
}
