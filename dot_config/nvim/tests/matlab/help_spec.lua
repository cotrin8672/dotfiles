describe("MATLAB help hover", function()
	local help
	local bufnr
	local client
	local notifications
	local previews
	local original_notify
	local original_preview
	local original_hover

	before_each(function()
		notifications = {}
		previews = {}
		client = {
			id = 42,
			supports_method = function()
				return false
			end,
			notify = function(_, method, params)
				table.insert(notifications, { method = method, params = params })
				return true
			end,
		}
		package.loaded["config.matlab.core"] = {
			get_diagnostic_client = function()
				return client, nil
			end,
		}
		package.loaded["config.matlab.help"] = nil
		help = require("config.matlab.help")
		help._reset_for_tests()

		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, bufnr)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "value = matlab.graphics.plot(x);" })
		vim.api.nvim_win_set_cursor(0, { 1, 24 })

		original_notify = vim.notify
		original_preview = vim.lsp.util.open_floating_preview
		original_hover = vim.lsp.buf.hover
		vim.notify = function(message, level)
			table.insert(previews, { notification = message, level = level })
		end
		vim.lsp.util.open_floating_preview = function(lines, filetype, opts)
			table.insert(previews, { lines = lines, filetype = filetype, opts = opts })
		end
	end)

	after_each(function()
		vim.notify = original_notify
		vim.lsp.util.open_floating_preview = original_preview
		vim.lsp.buf.hover = original_hover
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
		package.loaded["config.matlab.help"] = nil
		package.loaded["config.matlab.core"] = nil
	end)

	it("requests help from the analysis client and opens a hover-style float", function()
		assert.is_true(help.hover(bufnr))
		assert.are.equal("fevalRequest", notifications[1].method)
		assert.are.equal("help", notifications[1].params.functionName)
		assert.same({ "matlab.graphics.plot" }, notifications[1].params.args)
		assert.is_false(notifications[1].params.isUserEval)

		help.handle_response(nil, {
			requestId = notifications[1].params.requestId,
			result = { result = { "PLOT Plot data.\n" } },
		}, { client_id = 42 })
		assert.same({ "PLOT Plot data." }, previews[1].lines)
		assert.are.equal("text", previews[1].filetype)
		assert.matches("MATLAB Help: matlab.graphics.plot", previews[1].opts.title)
	end)

	it("prefers standard LSP hover when the analysis server supports it", function()
		local hover_opts
		client.server_capabilities = { hoverProvider = true }
		vim.lsp.buf.hover = function(opts)
			hover_opts = opts
		end

		assert.is_true(help.hover(bufnr))
		assert.same({ border = "rounded" }, hover_opts)
		assert.same({}, notifications)
	end)
end)
