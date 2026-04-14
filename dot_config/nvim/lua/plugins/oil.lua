return {
	"stevearc/oil.nvim",
	cmd = "Oil",
	keys = {
		{ "-", "<cmd>Oil<cr>", desc = "Oil: Parent dir" },
		{ "<leader>e", "<cmd>Oil --float<cr>", desc = "Oil: Float" },
		{ "<leader>O", "<cmd>Oil<cr>", desc = "Oil: CWD" },
	},
	config = function(_, opts)
		require("oil").setup(opts)

		vim.api.nvim_create_autocmd("User", {
			pattern = "OilActionsPost",
			callback = function(event)
				if event.data.actions[1].type == "move" then
					Snacks.rename.on_rename_file(event.data.actions[1].src_url, event.data.actions[1].dest_url)
				end
			end,
		})
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
