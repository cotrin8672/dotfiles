local M = {}
local registered = false

local function setup_auto_start(core)
	local requested_clients = {}

	local function request_start(client, bufnr)
		if not client or client.name ~= "matlab_ls" or requested_clients[client.id] then
			return
		end
		requested_clients[client.id] = true

		vim.defer_fn(function()
			if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "matlab" then
				return
			end

			local ok, err = core.ensure_client(bufnr)
			if not ok then
				require("config.matlab.status").blocked(err)
			end
		end, 500)
	end

	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("MatlabExecutionAutoStart", { clear = true }),
		callback = function(event)
			request_start(vim.lsp.get_client_by_id(event.data.client_id), event.buf)
		end,
	})

	for _, client in ipairs(vim.lsp.get_clients({ name = "matlab_ls" })) do
		for bufnr in pairs(client.attached_buffers or {}) do
			request_start(client, bufnr)
		end
	end
end

function M.setup()
	if registered then
		return
	end
	registered = true

	local core = require("config.matlab.core")
	local cmdwin = require("config.matlab.command_window")
	local exec = require("config.matlab.exec")

	core.setup({ connection_timeout_ms = 120000 })
	require("config.matlab.workspace").setup()
	require("config.matlab.editing").setup()
	require("config.matlab.commands")
	setup_auto_start(core)

	cmdwin.set_submit_callback(function(input, opts)
		if input ~= "" then
			return exec.eval(input, opts)
		end
		return true, nil
	end)

	cmdwin.set_interrupt_callback(function()
		exec.interrupt()
	end)
end

return M
