return {
	"nvim-mini/mini.surround",
	event = "VeryLazy",
	opts = {
		custom_surroundings = {
			l = {
				input = { "%[%[().-()%]%]" },
				output = { left = "[[", right = "]]" },
			},
		},
	},
}
