return {
	"cotrin8672/wise-backspace.nvim",
	event = { "BufReadPost", "BufNewFile", "InsertEnter", "CmdlineEnter" },
	opts = {
		ignored_filetypes = {
			"",
			"py",
			"md",
			"txt",
		},
		treesitter = {
			enabled = true,
			languages = {
				"lua",
			},
		},
	},
}
