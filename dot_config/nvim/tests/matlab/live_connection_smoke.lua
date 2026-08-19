local core = require("config.matlab.core")
local exec = require("config.matlab.exec")
local command_window = require("config.matlab.command_window")

local function command_output()
	local bufnr = command_window._snapshot().bufnr
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return ""
	end
	return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

local function request(client, method, params, bufnr)
	local response = assert(client:request_sync(method, params, 120000, bufnr), method .. " timed out")
	assert(response.err == nil, method .. " failed: " .. vim.inspect(response.err))
	return response.result
end

local function run()
	local completed = false
	local completion_ok = false
	local completion_result = nil
	local busy_start_marker = "NVIM_MATLAB_BUSY_START"
	local busy_end_marker = "NVIM_MATLAB_BUSY_END"
	local marker = "NVIM_MATLAB_LIVE_OK"
	local stderr_marker = "NVIM_MATLAB_STDERR_PROBE"
	local after_stderr_marker = "NVIM_MATLAB_STDOUT_AFTER_STDERR"

	local connected = vim.wait(180000, function()
		return core._snapshot().state == "connected"
	end, 100)
	assert(connected, "timed out waiting for MATLAB automatic connection")

	local source_bufnr = vim.api.nvim_get_current_buf()
	local diagnostic, diagnostic_err = core.get_diagnostic_client(source_bufnr)
	assert(diagnostic, diagnostic_err)

	local busy_accepted, busy_err = exec.eval(
		("fprintf(1, '%s\\n'); pause(90); fprintf(1, '%s\\n')"):format(busy_start_marker, busy_end_marker),
		{ bufnr = source_bufnr }
	)
	assert(busy_accepted, busy_err)
	assert(
		vim.wait(10000, function()
			return command_output():find(busy_start_marker, 1, true) ~= nil
		end, 50),
		"MATLAB busy marker was not received"
	)
	assert(not command_output():find(busy_end_marker, 1, true), "MATLAB busy command completed before LSP requests")

	vim.diagnostic.reset(nil, source_bufnr)
	vim.api.nvim_buf_set_lines(source_bufnr, 3, 3, false, { "unused_value = input;" })
	assert(
		vim.wait(10000, function()
			return #vim.diagnostic.get(source_bufnr) > 0
		end, 50),
		"diagnostics did not update while execution was busy"
	)

	local position_params = {
		textDocument = { uri = vim.uri_from_bufnr(source_bufnr) },
		position = { line = 2, character = 10 },
	}
	local definitions = request(diagnostic, "textDocument/definition", position_params, source_bufnr)
	local rename = request(diagnostic, "textDocument/prepareRename", position_params, source_bufnr)
	local completion = request(diagnostic, "textDocument/completion", position_params, source_bufnr)
	local completion_items = completion.items or completion

	assert(#definitions > 0, "definition request returned no target")
	assert(rename.placeholder == "value", "prepareRename returned the wrong symbol: " .. vim.inspect(rename))
	assert(#completion_items > 0, "completion request returned no items")
	assert(not command_output():find(busy_end_marker, 1, true), "execution finished before code intelligence requests")

	local interrupted, interrupt_err = exec.interrupt()
	assert(interrupted, interrupt_err)
	assert(
		vim.wait(10000, function()
			return command_window._snapshot().prompt == ">> "
		end, 50),
		"MATLAB command prompt did not recover after interrupt"
	)

	local accepted, err = exec.eval(
		("fprintf(1, '%s\\n'); fprintf(2, '%s\\n'); fprintf(1, '%s\\n')"):format(
			marker,
			stderr_marker,
			after_stderr_marker
		),
		{
			bufnr = source_bufnr,
			on_complete = function(ok, result)
				completed = true
				completion_ok = ok
				completion_result = result
			end,
		}
	)
	assert(accepted, err)

	local finished = vim.wait(180000, function()
		return completed or core._snapshot().state == "disconnected"
	end, 100)
	assert(finished, "timed out waiting for MATLAB live evaluation")
	assert(completed, "MATLAB disconnected before the live evaluation completed")
	assert(completion_ok, tostring(completion_result))
	assert(core._snapshot().state == "connected", "MATLAB was not connected after evaluation")
	assert(
		vim.wait(5000, function()
			return command_window._snapshot().prompt == ">> "
		end, 50),
		"MATLAB command prompt did not return to ready"
	)

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
	assert(
		vim.wait(10000, function()
			return core._snapshot().client_id == nil
		end, 50),
		"MATLAB execution client did not stop"
	)

	print("MATLAB live connection: busy execution, code intelligence, output, stop OK")
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
	pcall(core.stop_session)
	vim.api.nvim_err_writeln(err)
	vim.cmd("cquit")
end
