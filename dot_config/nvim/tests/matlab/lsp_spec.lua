describe("MATLAB LSP roles", function()
	it("keeps the diagnostic client disconnected and lets only the execution client launch MATLAB", function()
		package.loaded["config.matlab.lsp"] = nil
		local lsp = require("config.matlab.lsp")

		lsp.setup({})

		assert.equals("never", vim.lsp.config.matlab_ls.settings.MATLAB.matlabConnectionTiming)
		assert.is_nil(vim.lsp.config.matlab_ls.handlers)
		assert.equals(
			"onStart",
			lsp.exec_config(vim.api.nvim_get_current_buf(), {}, function() end).settings.MATLAB.matlabConnectionTiming
		)
	end)
end)
