return {
	"abecodes/tabout.nvim",
	event = { "VeryLazy", "InsertEnter" },
	opts = {
		tabouts = {
			{ open = "'", close = "'" },
			{ open = '"', close = '"' },
			{ open = "`", close = "`" },
			{ open = "(", close = ")" },
			{ open = "[", close = "]" },
			{ open = "{", close = "}" },
			{ open = "<", close = ">" },
		},
	},
}
