local cmdwin = require("config.matlab.command_window")

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
end

return M
