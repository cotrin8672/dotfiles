return {
	"windwp/nvim-ts-autotag",
	ft = {
		"astro",
		"eruby",
		"heex",
		"html",
		"javascriptreact",
		"php",
		"svelte",
		"typescriptreact",
		"vue",
		"xml",
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("nvim-ts-autotag").setup({
			opts = {
				enable_close = true,
				enable_rename = true,
				enable_close_on_slash = false,
			},
		})
	end,
}
