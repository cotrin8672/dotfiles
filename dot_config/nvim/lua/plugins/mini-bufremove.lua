return {
	"nvim-mini/mini.bufremove",
	keys = {
		{
			"<leader>x",
			function()
				vim.cmd("silent update")
				require("mini.bufremove").delete(0, false)
			end,
			desc = "Delete buffer",
		},
	},
}
