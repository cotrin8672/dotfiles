return {
	"nvimdev/lspsaga.nvim",
	event = "LspAttach",
	keys = {
		{
			"gra",
			"<cmd>Lspsaga code_action<cr>",
			mode = { "n", "x" },
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
