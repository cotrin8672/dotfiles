return {
	"lambdalisue/vim-kensaku-search",
	lazy = false,
	dependencies = {
		"lambdalisue/vim-kensaku",
	},
	init = function()
		vim.keymap.set("c", "<CR>", "<Plug>(kensaku-search-replace)<CR>", {
			silent = true,
			desc = "kensaku search replace",
		})
	end,
}
