return {
	"nvim-mini/mini.align",
	keys = {
		{ "ga", mode = { "n", "x" } },
		{ "<leader>al", mode = { "n", "x" } },
	},
	opts = {
		mappings = {
			start = "ga",
			start_with_preview = "<leader>al",
		},
	},
}
