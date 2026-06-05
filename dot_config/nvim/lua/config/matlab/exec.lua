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

function M.lines_command(start_line, end_line)
	local line_count = vim.api.nvim_buf_line_count(0)
	start_line = math.max(1, math.min(start_line, line_count))
	end_line = math.max(start_line, math.min(end_line, line_count))

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
	local command = table.concat(lines, "\n")
	if vim.trim(command) == "" then
		return nil, "selected MATLAB code is empty"
	end

	return command, nil
end

local function is_section_break(line)
	return line:find("^%s*%%%%") ~= nil
end

function M.current_cell_command()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	if #lines == 0 then
		return nil, "current buffer is empty"
	end

	local start_line = 1
	for line_number = row, 1, -1 do
		if is_section_break(lines[line_number] or "") then
			start_line = line_number
			break
		end
	end

	local end_line = #lines
	for line_number = row + 1, #lines do
		if is_section_break(lines[line_number] or "") then
			end_line = line_number - 1
			break
		end
	end

	return M.lines_command(start_line, end_line)
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
