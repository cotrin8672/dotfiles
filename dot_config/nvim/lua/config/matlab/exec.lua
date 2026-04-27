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

function M.command_from_current_file()
	local path, err = M.current_file()
	if not path then
		return nil, err
	end

	return matlab_command_from_file(path), nil
end

function M.eval(command)
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

function M.interrupt()
	local ok, err = core.notify("interruptRequest", {})

	if not ok then
		return false, err
	end

	return true, nil
end

function M.run_file()
	local command, err = M.command_from_current_file()
	if not command then
		return false, err
	end

	if vim.bo.modified then
		vim.cmd.write()
	end

	return M.eval(command)
end

return M
