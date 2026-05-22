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
	},
	keys = {
		"<leader>tc",
		"<cmd>Copilot toggle<cr>",
		desc = "Toggle Copilot",
	},
}
