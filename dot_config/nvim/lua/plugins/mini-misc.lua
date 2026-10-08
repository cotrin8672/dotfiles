return {
	"nvim-mini/mini.misc",
	event = "BufReadPre",
	config = function()
		require("mini.misc").setup_restore_cursor()
	end,
	keys = {
		{
			"<leader>u",
			function()
				vim.cmd("packadd nvim.undotree")
				vim.cmd("Undotree")
			end,
			mode = "n",
			desc = "Open Undotree",
		},
	},
}
