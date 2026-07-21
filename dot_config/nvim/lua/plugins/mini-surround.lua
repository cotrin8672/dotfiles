return {
	"nvim-mini/mini.surround",
	keys = {
		{ "sa", mode = { "n", "x" } },
		{ "sd", mode = "n" },
		{ "sf", mode = "n" },
		{ "sF", mode = "n" },
		{ "sh", mode = "n" },
		{ "sr", mode = "n" },
	},
	opts = {
		custom_surroundings = {
			l = {
				input = { "%[%[().-()%]%]" },
				output = { left = "[[", right = "]]" },
			},
		},
	},
}
