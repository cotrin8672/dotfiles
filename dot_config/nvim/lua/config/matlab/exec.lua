local core = require("config.matlab.core")

local M = {}

function M.current_file()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)

	if path == "" then
		return nil, "current buffer has no file name"
	end

	return path, nil
end

local function matlab_command_from_file(path)
	local filename = vim.fn.fnamemodify(path, ":t")
	local name = filename:gsub("%.m$", "")
	return name
end

function M.eval(command)
	local state = require("config.matlab.command_state")
	state.input(command)

	local ok, err = core.notify("evalRequest", {
		requestId = core.new_request_id(),
		command = command,
		isUserEval = true,
	})

	if not ok then
		return false, err
	end

	return true, nil
end

function M.run_file()
	local path, err = M.current_file()
	if not path then
		return false, err
	end

	if vim.bo.modified then
		vim.cmd.write()
	end

	local cmd = matlab_command_from_file(path)
	return M.eval(cmd)
end

return M
