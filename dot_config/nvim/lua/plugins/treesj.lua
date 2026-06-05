return {
	"Wansmer/treesj",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	keys = {
		{ "<leader>s", "<Cmd>TSJToggle<CR>" },
	},
	opts = function()
		return {
			use_default_keymaps = false,
			check_syntax_error = true,
			max_join_length = 120,
			cursor_behavior = "hold",
			notify = true,
			dot_repeat = true,
			langs = require("config.matlab.treesj").langs(),
		}
	end,
}
