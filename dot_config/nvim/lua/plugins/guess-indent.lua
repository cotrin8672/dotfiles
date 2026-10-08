return {
	"NMAC427/guess-indent.nvim",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		-- Java and Kotlin use four spaces, including files formatted on save.
		filetype_exclude = { "java", "kotlin" },
	},
}
