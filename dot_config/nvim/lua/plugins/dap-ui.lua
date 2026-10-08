return {
	"rcarriga/nvim-dap-ui",
	lazy = true,
	init = function()
		vim.api.nvim_create_user_command("DapUIOpen", function()
			require("dapui").open()
		end, { desc = "Open DAP UI" })
		vim.api.nvim_create_user_command("DapUIClose", function()
			require("dapui").close()
		end, { desc = "Close DAP UI" })
		vim.api.nvim_create_user_command("DapUIToggle", function()
			require("dapui").toggle()
		end, { desc = "Toggle DAP UI" })
	end,
	dependencies = {
		"mfussenegger/nvim-dap",
		"nvim-neotest/nvim-nio",
	},
	opts = {},
}
