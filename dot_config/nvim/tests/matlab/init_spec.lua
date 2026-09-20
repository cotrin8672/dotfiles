describe("MATLAB integration setup", function()
	local core
	local original_ensure_client
	local bufnr
	local ensured_buffers

	before_each(function()
		core = require("config.matlab.core")
		original_ensure_client = core.ensure_client
		ensured_buffers = {}

		core.ensure_client = function(target_bufnr)
			table.insert(ensured_buffers, target_bufnr)
			return true, nil
		end

		package.loaded["config.matlab"] = nil
		require("config.matlab").setup()

		bufnr = vim.api.nvim_create_buf(false, true)
		vim.bo[bufnr].filetype = "matlab"
	end)

	after_each(function()
		core.ensure_client = original_ensure_client
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("does not start a second MATLAB instance when the diagnostic client attaches", function()
		vim.api.nvim_exec_autocmds("LspAttach", {
			buffer = bufnr,
			data = { client_id = 41 },
		})
		vim.wait(600)

		assert.same({}, ensured_buffers)
	end)

	it("does not start MATLAB for another language server", function()
		vim.api.nvim_exec_autocmds("LspAttach", {
			buffer = bufnr,
			data = { client_id = 99 },
		})
		vim.wait(600)

		assert.same({}, ensured_buffers)
	end)

	it("keeps only the leader MATLAB mapping for creating sessions", function()
		assert.are.equal("<Cmd>MatlabNew<CR>", vim.fn.maparg("<leader>mn", "n"))
		assert.are.equal("", vim.fn.maparg("<leader>m]", "n"))
		assert.are.equal("", vim.fn.maparg("<leader>m[", "n"))
		assert.are.equal(2, vim.fn.exists(":MatlabNew"))
		assert.are.equal(2, vim.fn.exists(":MatlabNext"))
		assert.are.equal(2, vim.fn.exists(":MatlabPrev"))
	end)
end)
