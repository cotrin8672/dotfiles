return {
	"s-show/extend_word_motion.nvim",
	event = "VeryLazy",
	dependencies = {
		"sirasagi62/tinysegmenter.nvim",
	},
	opts = {},
	config = function(_, opts)
		require("extend_word_motion").setup(opts)
		for _, key in ipairs({ "w", "b", "e", "ge" }) do
			vim.keymap.del("s", key)
		end
	end,
}
