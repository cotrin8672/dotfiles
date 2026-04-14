return {
	"sindrets/diffview.nvim",
	cmd = {
		"DiffviewOpen",
		"DiffviewFileHistory",
		"DiffviewClose",
	},
	dependencies = {
		"plenary.nvim",
	},
	keys = {
		{
			"<leader>gd",
			function()
				local view = require("diffview.lib").get_current_view()
				if view then
					vim.cmd("DiffviewClose")
				else
					vim.cmd("DiffviewOpen")
				end
			end,
			desc = "Diffview Toggle",
		},
		{
			"<leader>gh",
			"<cmd>DiffviewFileHistory %<cr>",
			desc = "File History",
		},
	},
}
