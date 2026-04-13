return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	ft = { "markdown" },
	keys = {
		{
			"<leader>sm",
			":RenderMarkdown toggle<CR>",
			desc = "Toggle markdown renderer",
		},
	},
	opts = {},
}
