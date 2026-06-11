local cmdwin = require("config.matlab.command_window")
local core = require("config.matlab.core")

local M = {}

function M.setup()
	rawset(vim.lsp.handlers, "text", function(_, result)
		if result and result.text then
			cmdwin.handle_text(result.text)
		end
	end)

	rawset(vim.lsp.handlers, "clc", function()
		cmdwin.handle_clc()
	end)

	rawset(vim.lsp.handlers, "mvmPromptChange", function(_, result)
		if result and result.state then
			cmdwin.handle_prompt_change(result.state)
		end
	end)

	rawset(vim.lsp.handlers, "mvmStateChange", function(_, result)
		core.handle_mvm_state_change(result)
	end)

	rawset(vim.lsp.handlers, "matlab/launchfailed", function()
		core.handle_launch_failed()
	end)

	rawset(vim.lsp.handlers, "feature/needsmatlab/nomatlab", function()
		core.handle_launch_failed()
	end)
end

return M
