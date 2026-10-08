return {
	"akinsho/git-conflict.nvim",
	event = "BufReadPre",
	opts = {
		default_mappings = false,
		default_commands = true,
		disable_diagnostics = false,
		list_opener = "copen",
	},
	config = function(_, opts)
		require("git-conflict").setup(opts)

		vim.keymap.set("n", "]m", "<Plug>(git-conflict-next-conflict)", { desc = "Next Conflict" })
		vim.keymap.set("n", "[m", "<Plug>(git-conflict-prev-conflict)", { desc = "Previous Conflict" })
		vim.keymap.set("n", "<leader>go", "<Plug>(git-conflict-ours)", { desc = "Conflict Ours" })
		vim.keymap.set("n", "<leader>gt", "<Plug>(git-conflict-theirs)", { desc = "Conflict Theirs" })
		vim.keymap.set("n", "<leader>gb", "<Plug>(git-conflict-both)", { desc = "Conflict Both" })
		vim.keymap.set("n", "<leader>g0", "<Plug>(git-conflict-none)", { desc = "Conflict None" })
	end,
}
