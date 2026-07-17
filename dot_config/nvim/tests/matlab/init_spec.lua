describe("MATLAB integration setup", function()
	local core
	local original_ensure_client
	local original_get_client_by_id
	local bufnr
	local ensured_buffers

	before_each(function()
		core = require("config.matlab.core")
		original_ensure_client = core.ensure_client
		original_get_client_by_id = vim.lsp.get_client_by_id
		ensured_buffers = {}

		core.ensure_client = function(target_bufnr)
			table.insert(ensured_buffers, target_bufnr)
			return true, nil
		end
		vim.lsp.get_client_by_id = function(client_id)
			if client_id == 41 then
				return { id = client_id, name = "matlab_ls" }
			end
			return { id = client_id, name = "other_ls" }
		end

		package.loaded["config.matlab"] = nil
		require("config.matlab").setup()

		bufnr = vim.api.nvim_create_buf(false, true)
		vim.bo[bufnr].filetype = "matlab"
	end)

	after_each(function()
		core.ensure_client = original_ensure_client
		vim.lsp.get_client_by_id = original_get_client_by_id
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("starts the execution client after the diagnostic MATLAB client attaches", function()
		vim.api.nvim_exec_autocmds("LspAttach", {
			buffer = bufnr,
			data = { client_id = 41 },
		})

		assert.is_true(vim.wait(1000, function()
			return #ensured_buffers == 1
		end, 10))
		assert.same({ bufnr }, ensured_buffers)
	end)

	it("does not start MATLAB for another language server", function()
		vim.api.nvim_exec_autocmds("LspAttach", {
			buffer = bufnr,
			data = { client_id = 99 },
		})
		vim.wait(600)

		assert.same({}, ensured_buffers)
	end)
end)
