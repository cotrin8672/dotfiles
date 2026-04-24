local M = {}

function M.setup()
	local core = require("config.matlab.core")
	core.setup({
		auto_start = true,
		auto_start_delay = 500,
	})
	require("config.matlab.commands")
	require("config.matlab.command_state")
	require("config.matlab.handler").setup()
end

return M
