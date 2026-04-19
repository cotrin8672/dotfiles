return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	event = "InsertEnter",
	opts = {
		suggestion = {
			enabled = false,
		},
		panel = {
			enabled = false,
		},
		filetypes = {
			["*"] = false,
		},
	},
	keys = {
		"<leader>tc",
		"<cmd>Cipilot toggle<cr>",
		desc = "Toggle Copilot",
	},
}
