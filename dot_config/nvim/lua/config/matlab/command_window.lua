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

local function new_state(session_id)
	return {
		session_id = session_id,
		session_index = 1,
		session_count = 1,
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
		history = {},
		history_index = nil,
		history_draft = "",
	}
end

local states = { [1] = new_state(1) }
local active_session_id = 1
local state = states[active_session_id]
local on_submit = nil
local on_interrupt = nil
local animation_timer = nil
local animation_tick = 0
local busy_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local initializing_frames = { "◐", "◓", "◑", "◒" }
local sync_animation

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

local function get_hl_attr(groups, attr)
	for _, group in ipairs(groups) do
		local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
		if ok and hl[attr] then
			return hl[attr]
		end
	end
end

local function apply_winbar_highlights()
	vim.api.nvim_set_hl(0, "MatlabWinbarHead", { link = "TabbyHead" })
	vim.api.nvim_set_hl(0, "MatlabWinbarActive", { link = "TabbyActive" })
	vim.api.nvim_set_hl(0, "MatlabWinbarInactive", { link = "TabbyInactive" })
	vim.api.nvim_set_hl(0, "MatlabWinbarFill", { link = "TabbyFill" })

	local fill_bg = get_hl_attr({ "TabbyFill", "StatusLineNC", "Normal" }, "bg")
	vim.api.nvim_set_hl(0, "MatlabWinbarHeadSep", {
		fg = get_hl_attr({ "TabbyHead", "DiagnosticHint", "Normal" }, "bg"),
		bg = fill_bg,
	})
	vim.api.nvim_set_hl(0, "MatlabWinbarActiveSep", {
		fg = get_hl_attr({ "TabbyActive", "DiagnosticHint", "Normal" }, "bg"),
		bg = fill_bg,
	})
	vim.api.nvim_set_hl(0, "MatlabWinbarInactiveSep", {
		fg = get_hl_attr({ "TabbyInactive", "StatusLine", "Normal" }, "bg"),
		bg = fill_bg,
	})
end

apply_winbar_highlights()
local winbar_highlight_group = vim.api.nvim_create_augroup("MatlabCommandWindowWinbar", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
	group = winbar_highlight_group,
	callback = apply_winbar_highlights,
})

local function status_icon(session_state)
	if session_state.connection == "disconnected" then
		return "○"
	end
	if session_state.connection == "connecting" or session_state.prompt_kind == "INITIALIZING" then
		return initializing_frames[animation_tick % #initializing_frames + 1]
	end
	if session_state.prompt_kind == "BUSY" or session_state.prompt_kind == "COMPLETING_BLOCK" then
		return busy_frames[animation_tick % #busy_frames + 1]
	end
	if session_state.prompt_kind == "DEBUG" then
		return "◆"
	end
	if session_state.prompt_kind == "INPUT" or session_state.prompt_kind == "MORE" then
		return "?"
	end
	if session_state.prompt_kind == "PAUSE" then
		return "Ⅱ"
	end
	return "●"
end

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
	state.history_draft = ""
	state.history_index = nil
end

local function find_history(delta)
	local query = get_current_input()
	if query == nil then
		return
	end

	if not state.history_index then
		state.history_draft = query
		state.history_index = #state.history + 1
	end

	local i = state.history_index + delta
	local normalized_draft = state.history_draft:lower()
	while i >= 1 and i <= #state.history do
		local item = state.history[i]
		if state.history_draft == "" or vim.startswith(item:lower(), normalized_draft) then
			state.history_index = i
			set_current_input(item)
			return
		end
		i = i + delta
	end

	if delta > 0 then
		set_current_input(state.history_draft)
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

local function winbar_text()
	apply_winbar_highlights()

	local ordered = {}
	for _, session_state in pairs(states) do
		table.insert(ordered, session_state)
	end
	table.sort(ordered, function(left, right)
		return left.session_id < right.session_id
	end)
	local sessions_text = { "%#MatlabWinbarHead# 󰿈 %#MatlabWinbarHeadSep#" }
	for _, session_state in ipairs(ordered) do
		local active = session_state.session_id == active_session_id
		local body = active and "MatlabWinbarActive" or "MatlabWinbarInactive"
		local separator = active and "MatlabWinbarActiveSep" or "MatlabWinbarInactiveSep"
		local item = (" %%#%s#%%#%s# %d %s %%#%s#"):format(
			separator,
			body,
			session_state.session_id,
			status_icon(session_state),
			separator
		)
		table.insert(sessions_text, item)
	end
	return "%#MatlabWinbarFill# " .. table.concat(sessions_text) .. "%#MatlabWinbarFill#%="
end

local function render_winbar()
	if not is_visible() then
		return
	end
	vim.api.nvim_set_option_value("winbar", winbar_text(), { win = state.winid })
	sync_animation()
end

local function stop_animation()
	if animation_timer then
		animation_timer:stop()
		animation_timer:close()
		animation_timer = nil
	end
	animation_tick = 0
end

local function has_animated_session()
	if not is_visible() then
		return false
	end
	for _, session_state in pairs(states) do
		if
			session_state.connection == "connecting"
			or session_state.prompt_kind == "INITIALIZING"
			or session_state.prompt_kind == "BUSY"
			or session_state.prompt_kind == "COMPLETING_BLOCK"
		then
			return true
		end
	end
	return false
end

sync_animation = function()
	if not has_animated_session() then
		stop_animation()
		return
	end
	if animation_timer then
		return
	end
	animation_timer = assert(vim.uv.new_timer(), "failed to create MATLAB status animation timer")
	animation_timer:start(80, 80, vim.schedule_wrap(function()
		if not has_animated_session() then
			stop_animation()
			return
		end
		animation_tick = (animation_tick + 1) % 30
		render_winbar()
	end))
end

local function render_prompt(bufnr)
	state.prompt, state.status_text = current_prompt()
	vim.fn.prompt_setprompt(bufnr, state.prompt)
	render_winbar()
end

local function with_session(session_id, callback)
	if session_id == nil or session_id == active_session_id then
		return callback()
	end
	local previous = state
	state = states[session_id] or new_state(session_id)
	states[session_id] = state
	local ok, result, extra = xpcall(callback, debug.traceback)
	state = previous
	if not ok then
		error(result, 0)
	end
	if is_visible() then
		render_winbar()
	end
	return result, extra
end

local function configure_buffer(bufnr)
	local session_id = state.session_id
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
	vim.keymap.set("n", "<Tab>", "<Cmd>MatlabNext<CR>", {
		buffer = bufnr,
		noremap = true,
		silent = true,
		desc = "Matlab next session",
	})
	vim.keymap.set("n", "<S-Tab>", "<Cmd>MatlabPrev<CR>", {
		buffer = bufnr,
		noremap = true,
		silent = true,
		desc = "Matlab previous session",
	})

	for _, mode in ipairs({ "n", "i" }) do
		vim.keymap.set(mode, "<C-c>", function()
			if on_interrupt then
				on_interrupt(session_id)
			end
		end, { buffer = bufnr, noremap = true, silent = true })
	end

	vim.keymap.set("i", "<Up>", function()
		with_session(session_id, function()
			if #state.history > 0 then
				find_history(-1)
			end
		end)
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.keymap.set("i", "<Down>", function()
		with_session(session_id, function()
			if #state.history > 0 then
				find_history(1)
			end
		end)
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.fn.prompt_setcallback(bufnr, function(input)
		local ok, err = M.submit(input, { echo = false }, session_id)
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
	vim.api.nvim_buf_set_name(bufnr, ("[MATLAB Command Window %d]"):format(state.session_id))
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
	if state.history[#state.history] ~= command then
		table.insert(state.history, command)
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
	on_submit = fn
end

function M.set_interrupt_callback(fn)
	on_interrupt = fn
end

function M.submit(command, opts, session_id)
	return with_session(session_id, function()
		if command == "" then
			return true, nil
		end

		ensure_buffer()
		if on_submit then
			local ok, err = on_submit(command, opts, state.session_id)
			if ok == false then
				return false, err
			end
		end

		if opts == nil or opts.echo ~= false then
			append_input(command)
		end
		add_history(command)
		return true, nil
	end)
end

function M.handle_text(chunk, stream, session_id)
	return with_session(session_id, function()
		assert(type(chunk) == "string", "MATLAB text chunk must be a string")
		assert(type(stream) == "number", "MATLAB text stream must be a number")
		local text, severity = normalize_text_event(chunk:gsub("\r\n", "\n"):gsub("\r", "\n"), stream)
		if text == "" then
			return
		end
		append_text(text, severity)
		if severity == "error" and state.session_id == active_session_id and not is_visible() then
			M.open({ focus = false })
		end
	end)
end

function M.handle_clc(session_id)
	return with_session(session_id, function()
		local bufnr = ensure_buffer()
		state.output_tail = ""
		state.output_tail_severity = "normal"
		state.warning_active = false
		state.control_marker_tail = ""
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
		vim.api.nvim_buf_clear_namespace(bufnr, output_namespace, 0, -1)
		clear_history_state()
		render_prompt(bufnr)
	end)
end

function M.handle_connection_state(connection, opts)
	local session_id = opts and opts.session_id or nil
	return with_session(session_id, function()
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
	end)
end

function M.handle_input_prompt(prompt, session_id)
	return with_session(session_id, function()
		assert(type(prompt) == "string", "MATLAB input prompt must be a string")
		state.input_prompt = prompt
		if state.prompt_kind == "INPUT" and state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
			render_prompt(state.bufnr)
		end
	end)
end

function M.handle_prompt_change(kind, is_idle, session_id)
	return with_session(session_id, function()
		assert(valid_prompt_states[kind], "unknown MATLAB prompt state: " .. tostring(kind))
		assert(type(is_idle) == "boolean", "MATLAB prompt idle state must be a boolean")
		if kind ~= "BUSY" and kind ~= "INITIALIZING" then
			flush_output_tail()
		end
		state.prompt_kind = kind
		state.is_idle = is_idle
		local bufnr = ensure_buffer()
		render_prompt(bufnr)
		if
			state.session_id == active_session_id
			and (kind == "INPUT" or kind == "MORE" or kind == "PAUSE")
			and not is_visible()
		then
			M.open()
		end
	end)
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
		history = vim.deepcopy(state.history),
		session_id = state.session_id,
		session_index = state.session_index,
		session_count = state.session_count,
	}
end

function M._advance_animation_for_tests(steps)
	animation_tick = (animation_tick + (steps or 1)) % 30
	render_winbar()
end

function M.buffer_for_session(session_id)
	return with_session(session_id, ensure_buffer)
end

function M.select_session(session_id, session_count, session_index)
	local winid = is_visible() and state.winid or nil
	state.winid = nil
	active_session_id = session_id
	state = states[session_id] or new_state(session_id)
	states[session_id] = state
	state.session_index = session_index or session_id
	state.session_count = session_count
	if winid then
		state.winid = winid
		vim.api.nvim_set_option_value("winfixbuf", false, { win = winid })
		vim.api.nvim_win_set_buf(winid, ensure_buffer())
		vim.api.nvim_set_option_value("winfixbuf", true, { win = winid })
		render_prompt(state.bufnr)
	end
end

function M.remove_session(session_id)
	local session_state = states[session_id]
	if not session_state then
		return
	end
	local previous = state
	state = session_state
	close_window()
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		vim.api.nvim_buf_delete(state.bufnr, { force = true })
	end
	states[session_id] = nil
	state = previous
	if is_visible() then
		render_winbar()
	end
end

function M._reset_for_tests()
	stop_animation()
	for _, session_state in pairs(states) do
		state = session_state
		close_window()
		if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
			vim.api.nvim_buf_delete(state.bufnr, { force = true })
		end
	end
	states = { [1] = new_state(1) }
	active_session_id = 1
	state = states[1]
	on_submit = nil
	on_interrupt = nil
end

return M
