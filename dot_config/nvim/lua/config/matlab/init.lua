local M = {}
local initialized = false

function M.setup()
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
			exec.eval(input)
		end
	end)

	cmdwin.set_interrupt_callback(function()
		exec.interrupt()
	end)
	require("config.matlab.handler").setup()
	require("config.matlab.commands")
end

return M
