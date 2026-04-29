return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	ft = { "markdown" },
	keys = {
		{
			"<leader>tm",
			":RenderMarkdown toggle<CR>",
			desc = "Toggle markdown renderer",
		},
	},
	opts = {
		latex = {
			enabled = true,
		},
	},
}
