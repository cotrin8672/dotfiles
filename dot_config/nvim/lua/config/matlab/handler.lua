local state = require("config.matlab.command_state")

local M = {}

local function severity_from_text_event(text, stream)
	if stream == 0 then
		if vim.startswith(text, "Warning:") then
			return "warning"
		end
		return "normal"
	end

	return "error"
end

function M.setup()
	rawset(vim.lsp.handlers, "text", function(err, result)
		if err then
			state.append({
				text = "text notification error: " .. vim.inspect(err),
				severity = "error",
			})
		end

		if result and result.text then
			local severity = severity_from_text_event(result.text, result.stream)
			state.append({
				text = result.text,
				severity = severity,
			})
		end
	end)

	rawset(vim.lsp.handlers, "clc", function(err, _)
		if err then
			state.append({
				text = "clc notification error: " .. vim.inspect(err),
				severity = "error",
			})
		end
	end)
end

return M
