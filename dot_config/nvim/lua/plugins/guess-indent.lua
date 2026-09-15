return {
	"NMAC427/guess-indent.nvim",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		-- Kotlin is intentionally standardized to four spaces below.
		filetype_exclude = { "kotlin" },
	},
}
