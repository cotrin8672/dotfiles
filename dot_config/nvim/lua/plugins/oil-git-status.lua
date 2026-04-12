return {
	"refractalize/oil-git-status.nvim",
	dependencies = {
		"stevearc/oil.nvim",
	},
	cmd = "Oil",
	config = function()
		require("oil-git-status").setup()
	end,
}
