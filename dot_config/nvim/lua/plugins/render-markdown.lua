return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	ft = { "markdown", "codecompanion" },
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
