local M = {}

local output_namespace = vim.api.nvim_create_namespace("MatlabCommandWindowOutput")
local WARNING_START = "[\b"
local WARNING_END = "]\b"
local control_marker_chars = {
	["["] = true,
	["]"] = true,
	["{"] = true,
	["}"] = true,
}

local state = {
	bufnr = nil,
	winid = nil,
	connection = "disconnected",
	release = nil,
	prompt_kind = nil,
	prompt = "",
	status_text = nil,
	input_prompt = "? ",
	is_idle = true,
	output_tail = "",
	output_tail_severity = "normal",
	warning_active = false,
	control_marker_tail = "",
	on_submit = nil,
	on_interrupt = nil,
}

local prompt_map = {
	READY = ">> ",
	DEBUG = "K>> ",
	INPUT = "? ",
}

local status_map = {
	INITIALIZING = "MATLAB STARTING…",
	BUSY = "MATLAB RUNNING…",
	COMPLETING_BLOCK = "MATLAB WAITING FOR BLOCK…",
	PAUSE = "MATLAB PAUSED",
	MORE = "MATLAB WAITING FOR INPUT…",
}

local valid_prompt_states = {
	INITIALIZING = true,
	READY = true,
	BUSY = true,
	DEBUG = true,
	INPUT = true,
	PAUSE = true,
	MORE = true,
	COMPLETING_BLOCK = true,
}

local severity_rank = {
	normal = 1,
	warning = 2,
	error = 3,
}

local history = {}
local history_index = nil
local history_draft = ""

local function is_visible()
	return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

local function is_on_prompt_line()
	local bufnr = assert(state.bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	return row == vim.api.nvim_buf_line_count(bufnr)
end

local function get_current_input()
	if state.prompt == "" or not is_on_prompt_line() then
		return nil
	end
	local line = vim.api.nvim_get_current_line()
	if not vim.startswith(line, state.prompt) then
		return nil
	end
	return line:sub(#state.prompt + 1)
end

local function set_current_input(input)
	if state.prompt == "" or not is_on_prompt_line() then
		return
	end

	local line = state.prompt .. input
	local row = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_set_current_line(line)
	vim.api.nvim_win_set_cursor(0, { row, #line })
end

local function clear_history_state()
	history_draft = ""
	history_index = nil
end

local function find_history(delta)
	local query = get_current_input()
	if query == nil then
		return
	end

	if not history_index then
		history_draft = query
		history_index = #history + 1
	end

	local i = history_index + delta
	local normalized_draft = history_draft:lower()
	while i >= 1 and i <= #history do
		local item = history[i]
		if history_draft == "" or vim.startswith(item:lower(), normalized_draft) then
			history_index = i
			set_current_input(item)
			return
		end
		i = i + delta
	end

	if delta > 0 then
		set_current_input(history_draft)
		clear_history_state()
	end
end

local function close_window()
	if is_visible() then
		vim.api.nvim_win_close(state.winid, false)
	end
	state.winid = nil
end

local function jump_to_error(delta)
	local bufnr = assert(state.bufnr)
	local current_row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local rows = {}
	for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(bufnr, output_namespace, 0, -1, { details = true })) do
		if mark[4].hl_group == "ErrorMsg" then
			table.insert(rows, mark[2])
		end
	end
	if #rows == 0 then
		return
	end

	if delta > 0 then
		for _, row in ipairs(rows) do
			if row > current_row then
				vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
				return
			end
		end
		vim.api.nvim_win_set_cursor(0, { rows[1] + 1, 0 })
		return
	end

	for index = #rows, 1, -1 do
		if rows[index] < current_row then
			vim.api.nvim_win_set_cursor(0, { rows[index] + 1, 0 })
			return
		end
	end
	vim.api.nvim_win_set_cursor(0, { rows[#rows] + 1, 0 })
end

local function current_prompt()
	if state.connection == "disconnected" then
		return "", "MATLAB DISCONNECTED"
	end
	if state.connection == "connecting" then
		return "", "MATLAB STARTING…"
	end
	if state.prompt_kind == "INPUT" then
		return state.input_prompt ~= "" and state.input_prompt or prompt_map.INPUT, nil
	end
	if prompt_map[state.prompt_kind] then
		return prompt_map[state.prompt_kind], nil
	end
	if status_map[state.prompt_kind] then
		return "", status_map[state.prompt_kind]
	end
	return "", "MATLAB CONNECTED…"
end

local function render_winbar()
	if not is_visible() then
		return
	end

	local text = state.status_text
	if not text then
		text = state.release and ("MATLAB " .. state.release) or "MATLAB"
	end
	vim.api.nvim_set_option_value("winbar", " " .. text .. " ", { win = state.winid })
end

local function render_prompt(bufnr)
	state.prompt, state.status_text = current_prompt()
	vim.fn.prompt_setprompt(bufnr, state.prompt)
	render_winbar()
end

local function configure_buffer(bufnr)
	vim.bo[bufnr].buftype = "prompt"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].filetype = "matlab-command-window"

	vim.keymap.set("n", "q", close_window, { buffer = bufnr, noremap = true, silent = true, nowait = true })
	vim.keymap.set("n", "]e", function()
		jump_to_error(1)
	end, { buffer = bufnr, noremap = true, silent = true })
	vim.keymap.set("n", "[e", function()
		jump_to_error(-1)
	end, { buffer = bufnr, noremap = true, silent = true })

	for _, mode in ipairs({ "n", "i" }) do
		vim.keymap.set(mode, "<C-c>", function()
			if state.on_interrupt then
				state.on_interrupt()
			end
		end, { buffer = bufnr, noremap = true, silent = true })
	end

	vim.keymap.set("i", "<Up>", function()
		if #history > 0 then
			find_history(-1)
		end
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.keymap.set("i", "<Down>", function()
		if #history > 0 then
			find_history(1)
		end
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.fn.prompt_setcallback(bufnr, function(input)
		local ok, err = M.submit(input, { echo = false })
		if ok == false then
			vim.notify(tostring(err), vim.log.levels.ERROR)
		end
	end)
	render_prompt(bufnr)
end

local function ensure_buffer()
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		configure_buffer(state.bufnr)
		return state.bufnr
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, "[MATLAB Command Window]")
	state.bufnr = bufnr
	configure_buffer(bufnr)
	return bufnr
end

local function ensure_window()
	local bufnr = ensure_buffer()
	if is_visible() then
		return state.winid
	end

	vim.cmd("botright 12split")
	local winid = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(winid, bufnr)
	vim.api.nvim_set_option_value("winfixbuf", true, { win = winid })
	vim.w[winid].matlab_command_window = true
	state.winid = winid
	render_prompt(bufnr)
	return winid
end

local function highlight_group(severity)
	if severity == "warning" then
		return "WarningMsg"
	end
	if severity == "error" then
		return "ErrorMsg"
	end
	return nil
end

local function append_entries(entries)
	if #entries == 0 then
		return
	end

	local bufnr = ensure_buffer()
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local insert_at = math.max(line_count - 1, 0)
	local views = {}
	local following = {}
	for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
		if vim.api.nvim_win_is_valid(winid) then
			views[winid] = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
			following[winid] = vim.api.nvim_win_get_cursor(winid)[1] == line_count
		end
	end

	local lines = {}
	for index, entry in ipairs(entries) do
		lines[index] = entry.text
	end
	vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, lines)

	for index, entry in ipairs(entries) do
		local group = highlight_group(entry.severity)
		if group and entry.text ~= "" then
			vim.api.nvim_buf_set_extmark(bufnr, output_namespace, insert_at + index - 1, 0, {
				end_col = #entry.text,
				hl_group = group,
			})
		end
	end

	local new_last_line = vim.api.nvim_buf_line_count(bufnr)
	for winid, view in pairs(views) do
		if vim.api.nvim_win_is_valid(winid) then
			if following[winid] then
				vim.api.nvim_win_set_cursor(winid, { new_last_line, 0 })
			else
				vim.api.nvim_win_call(winid, function()
					vim.fn.winrestview(view)
				end)
			end
		end
	end
	render_prompt(bufnr)
end

local function stronger_severity(left, right)
	return severity_rank[left] >= severity_rank[right] and left or right
end

local function append_text(text, severity)
	if text == "" then
		return
	end

	local parts = vim.split(text, "\n", { plain = true })
	if #parts == 1 then
		state.output_tail = state.output_tail .. parts[1]
		state.output_tail_severity = stronger_severity(state.output_tail_severity, severity)
		return
	end

	local entries = {
		{
			text = state.output_tail .. parts[1],
			severity = stronger_severity(state.output_tail_severity, severity),
		},
	}
	for index = 2, #parts - 1 do
		table.insert(entries, { text = parts[index], severity = severity })
	end
	state.output_tail = parts[#parts]
	state.output_tail_severity = state.output_tail == "" and "normal" or severity
	append_entries(entries)
end

local function flush_output_tail()
	if state.control_marker_tail ~= "" then
		state.output_tail = state.output_tail .. state.control_marker_tail
		state.control_marker_tail = ""
	end
	if state.output_tail == "" then
		return
	end
	append_entries({ { text = state.output_tail, severity = state.output_tail_severity } })
	state.output_tail = ""
	state.output_tail_severity = "normal"
end

local function normalize_text_event(text, stream)
	text = state.control_marker_tail .. text
	state.control_marker_tail = ""
	local trailing = text:sub(-1)
	if control_marker_chars[trailing] then
		state.control_marker_tail = trailing
		text = text:sub(1, -2)
	end
	local warning_started = text:find(WARNING_START, 1, true) ~= nil
	local warning_ended = text:find(WARNING_END, 1, true) ~= nil
	local severity = "normal"
	if stream ~= 0 then
		severity = "error"
	elseif state.warning_active or warning_started then
		severity = "warning"
	end

	text = text:gsub("%[\b", ""):gsub("%]\b", ""):gsub("{\b", ""):gsub("}\b", "")
	if warning_started then
		state.warning_active = true
	end
	if warning_ended then
		state.warning_active = false
	end
	return text, severity
end

local function append_input(command)
	local command_lines = vim.split(command:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
	command_lines[1] = ">> " .. command_lines[1]
	for index = 2, #command_lines do
		command_lines[index] = "   " .. command_lines[index]
	end

	local entries = {}
	for index, line in ipairs(command_lines) do
		entries[index] = { text = line, severity = "normal" }
	end
	append_entries(entries)
end

local function add_history(command)
	if command == "" then
		return
	end
	if history[#history] ~= command then
		table.insert(history, command)
	end
	clear_history_state()
end

function M.open(opts)
	opts = opts or {}
	local source_winid = vim.api.nvim_get_current_win()
	local winid = ensure_window()
	local connection, release = require("config.matlab.core").connection_state()
	M.handle_connection_state(connection, { release = release })
	local bufnr = assert(state.bufnr)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	vim.api.nvim_win_set_cursor(winid, { line_count, 0 })

	if opts.focus == false then
		if vim.api.nvim_win_is_valid(source_winid) then
			vim.api.nvim_set_current_win(source_winid)
		end
		return winid
	end

	vim.api.nvim_set_current_win(winid)
	if state.prompt ~= "" then
		vim.cmd("startinsert")
	end
	return winid
end

function M.close()
	close_window()
end

function M.toggle()
	if is_visible() then
		close_window()
		return
	end
	M.open()
end

function M.is_command_window(winid)
	winid = winid or vim.api.nvim_get_current_win()
	return vim.api.nvim_win_is_valid(winid) and vim.w[winid].matlab_command_window == true
end

function M.set_submit_callback(fn)
	state.on_submit = fn
end

function M.set_interrupt_callback(fn)
	state.on_interrupt = fn
end

function M.submit(command, opts)
	if command == "" then
		return true, nil
	end

	ensure_buffer()
	if state.on_submit then
		local ok, err = state.on_submit(command, opts)
		if ok == false then
			return false, err
		end
	end

	if opts == nil or opts.echo ~= false then
		append_input(command)
	end
	add_history(command)
	return true, nil
end

function M.handle_text(chunk, stream)
	assert(type(chunk) == "string", "MATLAB text chunk must be a string")
	assert(type(stream) == "number", "MATLAB text stream must be a number")
	local text, severity = normalize_text_event(chunk:gsub("\r\n", "\n"):gsub("\r", "\n"), stream)
	if text == "" then
		return
	end
	append_text(text, severity)
	if severity == "error" and not is_visible() then
		M.open({ focus = false })
	end
end

function M.handle_clc()
	local bufnr = ensure_buffer()
	state.output_tail = ""
	state.output_tail_severity = "normal"
	state.warning_active = false
	state.control_marker_tail = ""
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
	vim.api.nvim_buf_clear_namespace(bufnr, output_namespace, 0, -1)
	clear_history_state()
	render_prompt(bufnr)
end

function M.handle_connection_state(connection, opts)
	assert(connection == "disconnected" or connection == "connecting" or connection == "connected")
	state.connection = connection
	state.release = opts and opts.release or nil
	if connection == "disconnected" then
		state.prompt_kind = nil
		state.input_prompt = "? "
		state.is_idle = true
	elseif connection == "connecting" then
		state.prompt_kind = "INITIALIZING"
	elseif state.prompt_kind == nil then
		state.prompt_kind = "INITIALIZING"
	end

	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		render_prompt(state.bufnr)
	end
end

function M.handle_input_prompt(prompt)
	assert(type(prompt) == "string", "MATLAB input prompt must be a string")
	state.input_prompt = prompt
	if state.prompt_kind == "INPUT" and state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		render_prompt(state.bufnr)
	end
end

function M.handle_prompt_change(kind, is_idle)
	assert(valid_prompt_states[kind], "unknown MATLAB prompt state: " .. tostring(kind))
	assert(type(is_idle) == "boolean", "MATLAB prompt idle state must be a boolean")
	if kind ~= "BUSY" and kind ~= "INITIALIZING" then
		flush_output_tail()
	end
	state.prompt_kind = kind
	state.is_idle = is_idle
	local bufnr = ensure_buffer()
	render_prompt(bufnr)
	if (kind == "INPUT" or kind == "MORE" or kind == "PAUSE") and not is_visible() then
		M.open()
	end
end

function M.severity_from_text_event(text, stream)
	if stream ~= 0 then
		return "error"
	end
	if state.warning_active or text:find(WARNING_START, 1, true) then
		return "warning"
	end
	return "normal"
end

function M._snapshot()
	return {
		bufnr = state.bufnr,
		winid = state.winid,
		connection = state.connection,
		prompt_kind = state.prompt_kind,
		prompt = state.prompt,
		status_text = state.status_text,
		output_tail = state.output_tail,
		history = vim.deepcopy(history),
	}
end

function M._reset_for_tests()
	close_window()
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		vim.api.nvim_buf_delete(state.bufnr, { force = true })
	end
	state.bufnr = nil
	state.connection = "disconnected"
	state.release = nil
	state.prompt_kind = nil
	state.prompt = ""
	state.status_text = nil
	state.input_prompt = "? "
	state.is_idle = true
	state.output_tail = ""
	state.output_tail_severity = "normal"
	state.warning_active = false
	state.control_marker_tail = ""
	state.on_submit = nil
	state.on_interrupt = nil
	history = {}
	clear_history_state()
end

return M
