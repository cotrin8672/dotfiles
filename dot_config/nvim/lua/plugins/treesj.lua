local function toggle_split_join()
	if vim.bo.filetype == "matlab" then
		return require("config.matlab.splitjoin").toggle()
	end

	return require("treesj").toggle()
end

return {
	"Wansmer/treesj",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	keys = {
		{ "<leader>s", toggle_split_join, desc = "Split/join" },
	},
	opts = function()
		return {
			use_default_keymaps = false,
			check_syntax_error = true,
			max_join_length = 120,
			cursor_behavior = "hold",
			notify = true,
			dot_repeat = true,
		}
	end,
}
