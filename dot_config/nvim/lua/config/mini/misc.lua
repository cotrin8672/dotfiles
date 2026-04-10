return function()
	require("mini.misc").setup_restore_cursor()

	vim.keymap.set("n", "<leader>u", function()
		vim.cmd("packadd nvim.undotree")
		vim.cmd("Undotree")
	end, { desc = "Open Undotree" })
end
