describe("MATLAB LSP roles", function()
	it("runs code intelligence and execution in separate MATLAB sessions", function()
		package.loaded["config.matlab.lsp"] = nil
		local lsp = require("config.matlab.lsp")

		lsp.setup({})

		assert.equals("onStart", vim.lsp.config.matlab_ls.settings.MATLAB.matlabConnectionTiming)
		assert.is_true(vim.lsp.config.matlab_ls.settings.MATLAB.indexWorkspace)
		assert.is_nil(vim.lsp.config.matlab_ls.handlers)

		local exec_config = lsp.exec_config(vim.api.nvim_get_current_buf(), {}, function() end)
		assert.equals("matlab_ls_exec", exec_config.name)
		assert.equals("onStart", exec_config.settings.MATLAB.matlabConnectionTiming)
		assert.is_false(exec_config.settings.MATLAB.indexWorkspace)
	end)
end)
