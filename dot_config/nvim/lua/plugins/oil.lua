return {
	"stevearc/oil.nvim",
	cmd = "Oil",
	keys = {
		{ "<leader>e", "<cmd>Oil --float<cr>", desc = "Oil: Float" },
	},
	config = function(_, opts)
		require("oil").setup(opts)
	end,
	opts = {
		default_file_explorer = true,
		float = {
			max_width = 0.7,
			max_height = 0.8,
		},
		win_options = {
			signcolumn = "yes:2",
			winblend = 10,
		},
		view_options = {
			show_hidden = true,
		},
		keymaps = {
			["<CR>"] = "actions.select",
			["<Esc>"] = "actions.close",
			["-"] = "actions.parent",
			["g."] = "actions.toggle_hidden",
		},
	},
}
