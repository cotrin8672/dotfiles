local M = {}

local group = vim.api.nvim_create_augroup("MatlabEditing", { clear = true })
local section_namespace = vim.api.nvim_create_namespace("MatlabSections")
local current_section_namespace = vim.api.nvim_create_namespace("MatlabCurrentSection")
local current_sections = {}
local section_rows = {}
local section_line_counts = {}

local function is_section_break(line)
	return line:find("^%s*%%%%") ~= nil
end

local function section_index_at_or_before(rows, row)
	local low, high = 1, #rows
	local index = 0
	while low <= high do
		local middle = math.floor((low + high) / 2)
		if rows[middle] <= row then
			index = middle
			low = middle + 1
		else
			high = middle - 1
		end
	end
	return index
end

local function highlight_sections(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, section_namespace, 0, -1)
	local rows = {}
	for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
		if is_section_break(line) then
			table.insert(rows, row)
			vim.api.nvim_buf_set_extmark(bufnr, section_namespace, row - 1, 0, {
				line_hl_group = "MatlabSectionOverline",
			})
		end
	end
	section_rows[bufnr] = rows
	section_line_counts[bufnr] = vim.api.nvim_buf_line_count(bufnr)
	current_sections[bufnr] = nil
end

local function highlight_current_section(bufnr)
	if vim.bo[bufnr].filetype ~= "matlab" then
		return
	end

	local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
	local current = current_sections[bufnr]
	if current and cursor_row >= current.start_row and cursor_row <= current.end_row then
		return
	end

	local rows = section_rows[bufnr] or {}
	local start_row = 1
	local end_row = vim.api.nvim_buf_line_count(bufnr)
	local section_index = section_index_at_or_before(rows, cursor_row)
	if section_index > 0 then
		start_row = rows[section_index]
	end
	if rows[section_index + 1] then
		end_row = rows[section_index + 1] - 1
	end

	local has_sections = #rows > 0
	current_sections[bufnr] = { start_row = start_row, end_row = end_row, visible = has_sections }
	vim.api.nvim_buf_clear_namespace(bufnr, current_section_namespace, 0, -1)
	if not has_sections then
		return
	end

	for row = start_row, end_row do
		vim.api.nvim_buf_set_extmark(bufnr, current_section_namespace, row - 1, 0, {
			sign_hl_group = "DiagnosticInfo",
			sign_text = "█",
		})
	end
end

local function insert_changed_section_boundaries(bufnr)
	if section_line_counts[bufnr] ~= vim.api.nvim_buf_line_count(bufnr) then
		return true
	end

	local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
	local rows = section_rows[bufnr] or {}
	local section_index = section_index_at_or_before(rows, cursor_row)
	local was_section = rows[section_index] == cursor_row
	return was_section ~= is_section_break(vim.api.nvim_get_current_line())
end

local function define_section_highlight()
	local title = vim.api.nvim_get_hl(0, { name = "Title", link = false })
	vim.api.nvim_set_hl(0, "MatlabSectionOverline", {
		bold = true,
		fg = title.fg,
		overline = true,
	})
end

local function rstrip(text)
	return (text:gsub("%s+$", ""))
end

local function line_parts_at_cursor()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	return row, col, line, line:sub(1, col), line:sub(col + 1)
end

local function code_before_comment(text)
	local comment_start = text:find("%%")
	if not comment_start then
		return text
	end
	return text:sub(1, comment_start - 1)
end

local function ends_with_any(text, suffixes)
	for _, suffix in ipairs(suffixes) do
		if text:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

local function should_continue_line(before_cursor, after_cursor)
	local code = rstrip(code_before_comment(before_cursor))

	if code == "" or code:find("%.%.%.$") then
		return false
	end

	if after_cursor:find("%S") and not after_cursor:find("^%s*%%") then
		return true
	end

	if code:find("[,%(%[]$") then
		return true
	end

	return ends_with_any(code, {
		"+",
		"-",
		"*",
		"/",
		"\\",
		"^",
		"=",
		"~",
		"<",
		">",
		"&",
		"|",
		".*",
		"./",
		".\\",
		".^",
	})
end

function M.newline()
	local _, _, _, before_cursor, after_cursor = line_parts_at_cursor()

	if should_continue_line(before_cursor, after_cursor) then
		return " ...<CR>"
	end

	return "<CR>"
end

function M.confirm_completion_or_newline()
	if require("blink.cmp").accept() then
		return ""
	end
	return M.newline()
end

function M.operator_split_join()
	local start = vim.api.nvim_buf_get_mark(0, "[")
	if start[1] > 0 then
		vim.api.nvim_win_set_cursor(0, start)
	end
	return require("config.matlab.splitjoin").toggle()
end

function M.toggle_split_join()
	vim.go.operatorfunc = "v:lua.require'config.matlab.editing'.operator_split_join"
	vim.api.nvim_feedkeys("g@l", "nix", true)
end

local function configure_buffer(bufnr)
	highlight_sections(bufnr)
	if vim.api.nvim_get_current_buf() == bufnr then
		highlight_current_section(bufnr)
	end

	vim.keymap.set("i", "<CR>", function()
		return M.confirm_completion_or_newline()
	end, { buffer = bufnr, expr = true, replace_keycodes = true, desc = "Matlab continuation newline" })

	vim.keymap.set("n", "<Plug>(MatlabSplitJoin)", M.toggle_split_join, {
		buffer = bufnr,
		silent = true,
	})

	vim.keymap.set("n", "<leader>s", M.toggle_split_join, {
		buffer = bufnr,
		desc = "Matlab split/join",
	})

	vim.keymap.set("n", "<leader>mr", "<Cmd>MatlabRunFile<CR>", {
		buffer = bufnr,
		desc = "Matlab run file",
	})

	vim.keymap.set("x", "<leader>ms", ":<C-u>MatlabRunVisual<CR>", {
		buffer = bufnr,
		desc = "Matlab run selection",
	})

	vim.keymap.set("n", "<leader>mc", "<Cmd>MatlabRunCell<CR>", {
		buffer = bufnr,
		desc = "Matlab run cell",
	})

	vim.keymap.set("n", "<leader>mi", "<Cmd>MatlabInterrupt<CR>", {
		buffer = bufnr,
		desc = "Matlab interrupt",
	})

	vim.keymap.set("n", "<leader>mw", "<Cmd>MatlabToggleCommandWindow<CR>", {
		buffer = bufnr,
		desc = "Matlab toggle command window",
	})

	vim.keymap.set("n", "<leader>fm", "<Cmd>MatlabWorkspace<CR>", {
		buffer = bufnr,
		desc = "Matlab toggle workspace",
	})

	vim.keymap.set("n", "<leader>fc", "<Cmd>MatlabSessions<CR>", {
		buffer = bufnr,
		desc = "Matlab sessions",
	})

	vim.keymap.set("n", "K", function()
		require("config.matlab.help").hover(bufnr)
	end, {
		buffer = bufnr,
		desc = "Matlab help",
	})
end

function M.setup()
	define_section_highlight()
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = define_section_highlight,
	})

	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "matlab",
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	vim.api.nvim_create_autocmd("TextChanged", {
		group = group,
		pattern = "*.m",
		callback = function(event)
			highlight_sections(event.buf)
			highlight_current_section(event.buf)
		end,
	})

	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		pattern = "*.m",
		callback = function(event)
			if insert_changed_section_boundaries(event.buf) then
				highlight_sections(event.buf)
			end
			highlight_current_section(event.buf)
		end,
	})

	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
		group = group,
		pattern = "*.m",
		callback = function(event)
			highlight_current_section(event.buf)
		end,
	})

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "matlab" then
			configure_buffer(bufnr)
		end
	end
end

return M
