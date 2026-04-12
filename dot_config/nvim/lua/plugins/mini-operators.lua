return {
	"nvim-mini/mini.operators",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		evaluate = { prefix = "g=" },
		exchange = { prefix = "gx" },
		multiply = { prefix = "gm" },
		replace = { prefix = "gR" },
		sort = { prefix = "gs" },
	},
}
