local M = {}
local initialized = false
local registered = false

local function initialize_lsp_integration()
	if initialized then
		return
	end
	initialized = true

	local core = require("config.matlab.core")
	local cmdwin = require("config.matlab.command_window")
	local exec = require("config.matlab.exec")
	core.setup({
		auto_start = true,
		auto_start_delay = 500,
	})

	cmdwin.set_submit_callback(function(input)
		if input ~= "" then
			return exec.eval(input)
		end
		return true, nil
	end)

	cmdwin.set_interrupt_callback(function()
		exec.interrupt()
	end)
	require("config.matlab.handler").setup()
	require("config.matlab.commands")
end

function M.setup()
	if registered then
		return
	end
	registered = true

	require("config.matlab.editing").setup()

	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("MatlabIntegration", { clear = true }),
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if not client or client.name ~= "matlab_ls" then
				return
			end

			initialize_lsp_integration()
		end,
	})
end

return M
