local core = require("config.matlab.core")
local exec = require("config.matlab.exec")
local command_window = require("config.matlab.command_window")

local function run()
	local completed = false
	local completion_ok = false
	local completion_result = nil
	local marker = "NVIM_MATLAB_LIVE_OK"
	local stderr_marker = "NVIM_MATLAB_STDERR_PROBE"
	local after_stderr_marker = "NVIM_MATLAB_STDOUT_AFTER_STDERR"

	local connected = vim.wait(180000, function()
		return core._snapshot().state == "connected"
	end, 100)
	assert(connected, "timed out waiting for MATLAB automatic connection")

	local accepted, err = exec.eval(("fprintf(1, '%s\\n'); fprintf(2, '%s\\n'); fprintf(1, '%s\\n')")
		:format(marker, stderr_marker, after_stderr_marker), {
		bufnr = vim.api.nvim_get_current_buf(),
		on_complete = function(ok, result)
			completed = true
			completion_ok = ok
			completion_result = result
		end,
	})
	assert(accepted, err)

	local finished = vim.wait(180000, function()
		return completed or core._snapshot().state == "disconnected"
	end, 100)
	assert(finished, "timed out waiting for MATLAB live evaluation")
	assert(completed, "MATLAB disconnected before the live evaluation completed")
	assert(completion_ok, tostring(completion_result))
	assert(core._snapshot().state == "connected", "MATLAB was not connected after evaluation")
	assert(vim.wait(5000, function()
		return command_window._snapshot().prompt == ">> "
	end, 50), "MATLAB command prompt did not return to ready")

	local bufnr = command_window._snapshot().bufnr
	assert(bufnr and vim.api.nvim_buf_is_valid(bufnr), "MATLAB command window was not created")
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local output = table.concat(lines, "\n")
	assert(output:find(marker, 1, true), "MATLAB live output marker was not received")
	assert(output:find(stderr_marker, 1, true), "MATLAB stderr marker was not received")
	assert(output:find(after_stderr_marker, 1, true), "MATLAB output after stderr was not received")
	assert(not output:find("MATLAB RUNNING", 1, true), "MATLAB lifecycle status leaked into command output")

	local stderr_row = nil
	local after_stderr_row = nil
	for index, line in ipairs(lines) do
		if line == stderr_marker then
			stderr_row = index - 1
		elseif line == after_stderr_marker then
			after_stderr_row = index - 1
		end
	end
	assert(stderr_row, "MATLAB stderr marker row was not found")
	assert(after_stderr_row, "MATLAB output-after-stderr row was not found")

	local namespace = vim.api.nvim_get_namespaces().MatlabCommandWindowOutput
	local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, { details = true })
	assert(#marks == 1, "unexpected MATLAB output highlight count: " .. #marks)
	assert(marks[1][2] == stderr_row, "stderr highlight was placed on the wrong output row")
	assert(marks[1][2] ~= after_stderr_row, "stderr highlight leaked onto normal output")
	assert(marks[1][4].hl_group == "ErrorMsg", "stderr did not use the theme ErrorMsg highlight")
	assert(marks[1][4].line_hl_group == nil, "stderr used a full-line highlight")

	local winid = command_window.open({ focus = false })
	assert(vim.wo[winid].winbar == " MATLAB R2024a ", "MATLAB lifecycle state was not shown in the winbar")

	local stopped, stop_err = core.stop_session()
	assert(stopped, stop_err)
	assert(vim.wait(10000, function()
		return core._snapshot().client_id == nil
	end, 50), "MATLAB execution client did not stop")

	print("MATLAB live connection: connect, evaluate, output, stop OK")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
	pcall(core.stop_session)
	vim.api.nvim_err_writeln(err)
	vim.cmd("cquit")
end
