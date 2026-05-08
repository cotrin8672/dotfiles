local M = {}

local state = {
	bufnr = nil,
	winid = nil,
	prompt = ">> ",
	output_tail = "",
	on_submit = nil,
	on_interrupt = nil,
}

local prompt_map = {
	READY = ">> ",
	DEBUG = "K>> ",
	BUSY = "",
	COMPLETING_BLOCK = "",
	PAUSE = "",
	INPUT = "?",
	MORE = "",
	INITIALIZING = "",
}

local history = {}
local history_index = nil
local history_draft = ""

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

	while i >= 1 and i <= #history do
		local item = history[i]

		if history_draft == "" or vim.startswith(item, history_draft) then
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

local function configure_buffer(bufnr)
	vim.bo[bufnr].buftype = "prompt"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false

	vim.keymap.set("n", "<C-c>", function()
		if state.on_interrupt then
			state.on_interrupt()
		end
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.keymap.set("i", "<C-c>", function()
		if state.on_interrupt then
			state.on_interrupt()
		end
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.keymap.set("i", "<Up>", function()
		if #history == 0 then
			return
		end

		find_history(-1)
	end, { buffer = bufnr, noremap = true, silent = true })

	vim.keymap.set("i", "<Down>", function()
		if #history == 0 then
			return
		end

		find_history(1)
	end, { buffer = bufnr, noremap = true, silent = true })
	vim.fn.prompt_setprompt(bufnr, state.prompt)
	vim.fn.prompt_setcallback(bufnr, function(input)
		M.submit(input, { echo = false })
	end)
end

local function ensure_buffer()
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		configure_buffer(state.bufnr)
		return assert(state.bufnr)
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	configure_buffer(bufnr)

	state.bufnr = bufnr
	return assert(bufnr)
end

local function ensure_window()
	local bufnr = ensure_buffer()

	if state.winid and vim.api.nvim_win_is_valid(state.winid) then
		vim.api.nvim_win_set_buf(state.winid, bufnr)
		return assert(state.winid)
	end

	vim.cmd("botright 12split")
	local winid = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(winid, bufnr)

	state.winid = winid
	return assert(winid)
end

local function append_lines(lines)
	if #lines == 0 then
		return
	end

	local bufnr = ensure_buffer()
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local insert_at = math.max(line_count - 1, 0)

	vim.api.nvim_buf_set_lines(bufnr, insert_at, insert_at, false, lines)
end

local function append_input(command)
	append_lines({ ">> " .. command })
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

function M.open()
	ensure_window()
	vim.cmd("startinsert")
end

function M.set_submit_callback(fn)
	state.on_submit = fn
end

function M.set_interrupt_callback(fn)
	state.on_interrupt = fn
end

function M.submit(command, opts)
	if command == "" then
		return
	end

	ensure_window()
	if opts == nil or opts.echo then
		append_input(command)
	end

	if state.on_submit then
		state.on_submit(command)
	end
	add_history(command)
end

function M.handle_text(chunk)
	local text = (state.output_tail .. chunk):gsub("\r\n", "\n"):gsub("\r", "\n")
	local lines = vim.split(text, "\n", { plain = true })

	state.output_tail = table.remove(lines) or ""
	append_lines(lines)
end

function M.handle_clc()
	local bufnr = ensure_buffer()
	state.output_tail = ""
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
	vim.fn.prompt_setprompt(bufnr, state.prompt)
	clear_history_state()
end

function M.handle_prompt_change(kind)
	state.prompt = prompt_map[kind] or ""
	local bufnr = ensure_buffer()
	vim.fn.prompt_setprompt(bufnr, state.prompt)
end

function M.severity_from_text_event(text, stream)
	if stream == 0 then
		if vim.startswith(text, "Warning:") then
			return "warning"
		end
		return "normal"
	end

	return "error"
end
return M
