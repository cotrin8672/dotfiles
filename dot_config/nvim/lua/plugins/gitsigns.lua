return {
	"lewis6991/gitsigns.nvim",
	-- gitsigns registers its attach path on BufRead/BufNewFile/BufFilePost.
	-- Loading it after those events leaves the current buffer unattached.
	event = { "BufReadPost", "BufNewFile", "BufFilePost" },
	opts = {},
}
