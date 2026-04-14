return {
	"qwavies/smart-backspace.nvim",
	event = { "InsertEnter", "CmdlineEnter" },
	opts = {
		enabled = true,
		silent = true,
		disabled_filetypes = {
			"",
			"py",
			"hs",
			"md",
			"txt",
		},
	},
}
