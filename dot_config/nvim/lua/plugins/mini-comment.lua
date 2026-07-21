return {
	"nvim-mini/mini.comment",
	keys = {
		{ "gc", mode = { "n", "x", "o" } },
		{ "gcc", mode = "n" },
	},
	opts = {
		mappings = {
			comment = "gc",
			comment_line = "gcc",
			comment_visual = "gc",
			textobject = "gc",
		},
	},
}
