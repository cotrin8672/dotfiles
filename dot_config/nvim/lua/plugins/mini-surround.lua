return {
	"nvim-mini/mini.surround",
	keys = { "sa", "sd", "sf", "sF", "sh", "sr", "sn" },
	opts = {
		custom_surroundings = {
			l = {
				input = { "%[%[().-()%]%]" },
				output = { left = "[[", right = "]]" },
			},
		},
	},
}
