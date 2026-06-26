return {
	"zbirenbaum/copilot.lua",
	cmd = "Copilot",
	init = function()
		vim.g.copilot_enabled = false
	end,
	opts = {
		suggestion = {
			enabled = false,
		},
		panel = {
			enabled = false,
		},
	},
	keys = {
		{
			"<leader>tc",
			function()
				vim.g.copilot_enabled = not vim.g.copilot_enabled
				vim.cmd(vim.g.copilot_enabled and "Copilot enable" or "Copilot disable")
			end,
			desc = "Toggle Copilot",
		},
	},
}
