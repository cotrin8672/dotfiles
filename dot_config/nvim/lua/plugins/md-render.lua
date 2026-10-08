return {
	"delphinus/md-render.nvim",
	dependencies = {
		"delphinus/budoux.lua",
	},
	keys = {
		{
			"<leader>mt",
			"<Plug>(md-render-preview)",
			desc = "Toggle markdown preview",
		},
	},
}
