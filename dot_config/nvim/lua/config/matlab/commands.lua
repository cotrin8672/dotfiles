local core = require("config.matlab.core")

local M = {}

local function notify_error(message)
	vim.notify(tostring(message), vim.log.levels.ERROR)
end

local function submit(command, opts)
	local ok, err = require("config.matlab.command_window").submit(command, opts)
	if ok == false then
		notify_error(err)
		return false
	end
	return true
end

function M.run_file()
	local exec = require("config.matlab.exec")
	local bufnr = vim.api.nvim_get_current_buf()

	if vim.bo[bufnr].modified then
		vim.cmd.write()
	end

	local command, err = exec.command_from_current_file()
	if not command then
		notify_error(err)
		return false
	end

	return submit(command, { bufnr = bufnr })
end

function M.run_lines(start_line, end_line)
	local exec = require("config.matlab.exec")
	local command, err = exec.lines_command(start_line, end_line)
	if not command then
		notify_error(err)
		return false
	end

	return submit(command, { bufnr = vim.api.nvim_get_current_buf() })
end

function M.run_visual_selection()
	local exec = require("config.matlab.exec")
	local command, err = exec.visual_selection_command(
		vim.fn.getpos("'<"),
		vim.fn.getpos("'>"),
		vim.fn.visualmode()
	)
	if not command then
		notify_error(err)
		return false
	end

	return submit(command, { bufnr = vim.api.nvim_get_current_buf() })
end

function M.run_cell()
	local exec = require("config.matlab.exec")
	local source_winid = vim.api.nvim_get_current_win()
	local source_bufnr = vim.api.nvim_get_current_buf()
	local command, err, next_cell_line = exec.current_cell_command()
	if not command then
		notify_error(err)
		return false
	end

	if not submit(command, { bufnr = source_bufnr }) then
		return false
	end

	if next_cell_line then
		vim.api.nvim_win_set_cursor(source_winid, { next_cell_line, 0 })
		vim.api.nvim_win_call(source_winid, function()
			vim.cmd.normal({ args = { "zz" }, bang = true })
		end)
	end

	return true
end

vim.api.nvim_create_user_command("MatlabClientInfo", function()
	local diagnostic = core.get_diagnostic_client(0)
	local execution = core.get_exec_client()
	local snapshot = core._snapshot()

	vim.notify(vim.inspect({
		diagnostic = diagnostic and { id = diagnostic.id, name = diagnostic.name } or nil,
		execution = execution and { id = execution.id, name = execution.name } or nil,
		connection = snapshot.state,
		release = snapshot.release,
		root = snapshot.root_dir,
		queued = snapshot.queue_length,
		running = snapshot.inflight_request_id ~= nil,
	}))
end, { force = true })

vim.api.nvim_create_user_command("MatlabDocumentSymbols", function()
	local bufnr = vim.api.nvim_get_current_buf()

	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
	}
	local _, err = core.request_diagnostic("textDocument/documentSymbol", params, function(request_err, result)
		if request_err then
			vim.notify("request error: " .. vim.inspect(request_err), vim.log.levels.ERROR)
			return
		end

		if not result or vim.tbl_isempty(result) then
			vim.notify("no symbols found", vim.log.levels.WARN)
			return
		end

		local names = {}
		for _, symbol in ipairs(result) do
			table.insert(names, symbol.name)
		end

		vim.notify("symbols: \n" .. table.concat(names, "\n"))
	end, bufnr)

	if err then
		notify_error(err)
	end
end, { force = true })

vim.api.nvim_create_user_command("MatlabCurrentFile", function()
	local path, err = require("config.matlab.exec").current_file()
	if not path then
		notify_error(err)
		return
	end

	vim.notify(path)
end, { force = true })

vim.api.nvim_create_user_command("MatlabRunFile", M.run_file, { force = true })

vim.api.nvim_create_user_command("MatlabRunSelection", function(opts)
	M.run_lines(opts.line1, opts.line2)
end, { range = true, force = true })

vim.api.nvim_create_user_command("MatlabRunVisual", M.run_visual_selection, { force = true })

vim.api.nvim_create_user_command("MatlabRunCell", M.run_cell, { force = true })

vim.api.nvim_create_user_command("MatlabEval", function(opts)
	submit(opts.args, { bufnr = vim.api.nvim_get_current_buf() })
end, { nargs = "+", force = true })

vim.api.nvim_create_user_command("MatlabInterrupt", function()
	require("config.matlab.exec").interrupt()
end, { force = true })

vim.api.nvim_create_user_command("MatlabCancelQueue", function()
	require("config.matlab.exec").cancel_queued()
end, { force = true })

vim.api.nvim_create_user_command("MatlabStop", function()
	local ok, err = require("config.matlab.exec").stop()
	if ok == false then
		notify_error(err)
	end
end, { force = true })

vim.api.nvim_create_user_command("MatlabRestartHere", function()
	local ok, err = require("config.matlab.exec").restart_here(vim.api.nvim_get_current_buf())
	if ok == false then
		notify_error(err)
	end
end, { force = true })

vim.api.nvim_create_user_command("MatlabOpenCommandWindow", function()
	require("config.matlab.command_window").open()
end, { force = true })

vim.api.nvim_create_user_command("MatlabCommandWindow", function()
	require("config.matlab.command_window").open()
end, { force = true })

vim.api.nvim_create_user_command("MatlabToggleCommandWindow", function()
	require("config.matlab.command_window").toggle()
end, { force = true })

vim.api.nvim_create_user_command("MatlabWorkspace", function()
	require("config.matlab.workspace").toggle()
end, { force = true })

return M
