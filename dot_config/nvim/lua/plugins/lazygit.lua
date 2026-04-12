return {
	{
		"nvim-lua/plenary.nvim",
		lazy = true,
	},
	{
		"kdheepak/lazygit.nvim",
		opts = {
			float = {
				width = 0.88,
				height = 0.88,
			},
		},
		cmd = {
			"LazyGit",
			"LazyGitConfig",
			"LazyGitCurrentFile",
			"LazyGitFilter",
			"LazyGitFilterCurrentFile",
		},
		dependencies = {
			"plenary.nvim",
		},
	},
}
