local M = {}

local group = vim.api.nvim_create_augroup("MatlabEditing", { clear = true })
local section_namespace = vim.api.nvim_create_namespace("MatlabSections")
local current_section_namespace = vim.api.nvim_create_namespace("MatlabCurrentSection")
local current_sections = {}
local section_rows = {}
local section_line_counts = {}
local section_changes = {}
local section_attached = {}
local repeat_namespace = vim.api.nvim_create_namespace("MatlabInsertRepeat")
local last_insert_ticks = {}

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

local function normal_changed_section_boundaries(bufnr)
	local changed = section_changes[bufnr]
	if not changed or changed.lines or section_line_counts[bufnr] ~= vim.api.nvim_buf_line_count(bufnr) then
		return true
	end
	local rows = section_rows[bufnr] or {}
	local last_section = rows[section_index_at_or_before(rows, changed.last)]
	if last_section and last_section > changed.first then
		return true
	end
	for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, changed.first, changed.last, false)) do
		if is_section_break(line) then
			return true
		end
	end
	return false
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

local function ends_with_any(text, suffixes)
	for _, suffix in ipairs(suffixes) do
		if text:sub(-#suffix) == suffix then
			return true
		end
	end
	return false
end

local operators = { "+", "-", "*", "/", "\\", "^", "=", "~", "<", ">", "&", "|", ":" }

local function should_continue_line(before, after_cursor, depth)
	local code = rstrip(before.code)

	if before.in_comment or before.quote then
		return false
	end
	if code:find(";$") or (code:find(",$") and depth == 0) then
		return false
	end
	if depth > 0 then
		return true
	end
	if code == "" then
		return false
	end

	if after_cursor:find("%S") and not after_cursor:find("^%s*%%") then
		return true
	end

	if code:find("[,%(%[{]$") then
		return true
	end

	return ends_with_any(code, operators)
end

function M.newline()
	local row, col, text, before_cursor, after_cursor = line_parts_at_cursor()
	local syntax = require("config.matlab.syntax")
	local context = syntax.context(vim.api.nvim_get_current_buf(), row - 1)
	local before = syntax.line(before_cursor, context.in_block_comment)
	local full = syntax.line(text, context.in_block_comment)
	local depth = syntax.depth((context.logical and context.logical.code or "") .. " " .. before.code)
	local command = "<Cmd>lua require('config.matlab.editing')."
	if full.continuation_start and col >= full.continuation_start and col < full.continuation_start + 2 then
		return "<CR>"
	end
	if before.in_comment and not context.in_block_comment and after_cursor:find("%S") then
		local marker = before.continuation and "..." or "%"
		return "<CR>" .. command .. "finish_comment('" .. marker .. "')<CR>"
	end
	if
		before.comment_start
		and not after_cursor:find("%S")
		and should_continue_line({ code = before.code }, "", depth)
	then
		return "<CR>" .. command .. "finish_commented_continuation()<CR>"
	end
	local blank_continuation = context.logical
		and not before.in_comment
		and not before.quote
		and not before.code:find("%S")
	local closing_only = syntax.line(after_cursor).code:match("^%s*[%)%]}]+%s*;?%s*$")
	if depth > 0 and closing_only and not before.in_comment and not before.quote then
		local prefix = rstrip(before.code):find(";$") and "" or " ..."
		return prefix .. "<CR>" .. command .. "finish_pair()<CR>"
	end
	if should_continue_line(before, after_cursor, depth) or blank_continuation or before.continuation then
		local tail_ellipsis = after_cursor:match("^%s*%.%.%.%s*$")
		local prefix = tail_ellipsis and "<End>" or (before.continuation and "" or " ...")
		local close = { ["("] = ")", ["["] = "]", ["{"] = "}" }
		local opening = rstrip(before.code):sub(-1)
		if close[opening] and vim.trim(after_cursor):sub(1, 1) == close[opening] then
			return prefix .. "<CR>" .. command .. "finish_pair()<CR>"
		end
		if not after_cursor:find("%S") or tail_ellipsis then
			return prefix .. "<CR>" .. command .. "finish_continuation()<CR>"
		end
		return prefix .. "<CR>"
	end

	if not before.continuation and not before.quote and not after_cursor:find("%S") then
		return "<CR>" .. command .. "finish_block()<CR>"
	end

	return "<CR>"
end

function M.finish_commented_continuation()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local text = vim.api.nvim_buf_get_lines(0, row - 2, row - 1, false)[1]
	local comment = require("config.matlab.syntax").line(text).comment_start
	if not comment then
		return
	end
	local prefix = text:sub(comment - 1, comment - 1):match("%s") and "... " or " ... "
	vim.cmd("undojoin")
	vim.api.nvim_buf_set_text(0, row - 2, comment - 1, row - 2, comment - 1, { prefix })
	local indent = require("config.matlab").indent(row)
	local body = vim.bo.expandtab and string.rep(" ", indent) or string.rep("\t", math.floor(indent / vim.bo.tabstop))
	vim.api.nvim_set_current_line(body)
	vim.api.nvim_win_set_cursor(0, { row, #body })
	M.finish_continuation()
end

function M.finish_comment(marker)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local native_comment = line:sub(1, col):match("^(%s*)%%%s*$")
	if native_comment then
		vim.cmd("undojoin")
		vim.api.nvim_buf_set_text(0, row - 1, 0, row - 1, col, { native_comment .. marker .. " " })
		col = #native_comment
	else
		vim.cmd("undojoin")
		vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { marker .. " " })
	end
	vim.api.nvim_win_set_cursor(0, { row, col + #marker + 1 })
end

function M.finish_pair()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local logical = require("config.matlab.syntax").context(vim.api.nvim_get_current_buf(), row - 1).logical
	local opener = logical.delimiter and logical.delimiter.line or logical.line
	local before = vim.api.nvim_buf_get_lines(0, opener - 1, opener, false)[1]
	local unit = before:match("^%s*") .. (vim.bo.expandtab and string.rep(" ", vim.fn.shiftwidth()) or "\t")
	vim.cmd("undojoin")
	vim.api.nvim_buf_set_lines(0, row - 1, row - 1, false, { unit .. " ..." })
	vim.api.nvim_win_set_cursor(0, { row, #unit })
end

function M.finish_continuation()
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local syntax = require("config.matlab.syntax")
	local context = syntax.context(bufnr, row - 1)
	if not context.logical then
		return
	end
	local text = vim.api.nvim_get_current_line()
	if text:find("%S") and not text:match("^%s*%.%.%.%s*$") then
		return
	end
	local next_line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
	local previous = syntax.line(vim.api.nvim_buf_get_lines(bufnr, row - 2, row - 1, false)[1]).code
	if
		next_line
		and next_line:match("^%s*[%)%]}]")
		and not rstrip(previous):find(",$")
		and not ends_with_any(rstrip(previous), operators)
	then
		vim.cmd("undojoin")
		vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, {})
		vim.api.nvim_win_set_cursor(0, { row, #(next_line:match("^%s*") or "") })
	elseif next_line and not next_line:match("^%s*end%s*[;,]?%s*$") then
		local indent = text:match("^%s*")
		vim.cmd("undojoin")
		vim.api.nvim_set_current_line(indent .. " ...")
		vim.api.nvim_win_set_cursor(0, { row, #indent })
	end
end

function M.finish_block()
	local bufnr = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local header = require("config.matlab.syntax").needs_end(bufnr, row - 1)
	if not header or vim.api.nvim_get_current_line():find("%S") then
		return
	end
	local line = vim.api.nvim_buf_get_lines(bufnr, header.line - 1, header.line, false)[1]
	local indent = line:match("^%s*")
	local unit = vim.bo.expandtab and string.rep(" ", vim.fn.shiftwidth()) or "\t"
	vim.cmd("undojoin")
	vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { indent .. unit, indent .. "end" })
	vim.api.nvim_win_set_cursor(0, { row, #indent + #unit })
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

local function setup_insert_repeat()
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = function(event)
			if vim.bo[event.buf].filetype == "matlab" then
				last_insert_ticks[event.buf] = vim.api.nvim_buf_get_changedtick(event.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(event)
			last_insert_ticks[event.buf] = nil
		end,
	})
	-- Dot replays insert text without invoking expression mappings or their
	-- buffer edits. Repair only the most recent insert, after native replay.
	vim.on_key(function(key)
		if key ~= "." or vim.api.nvim_get_mode().mode ~= "n" or vim.bo.filetype ~= "matlab" then
			return
		end
		local bufnr = vim.api.nvim_get_current_buf()
		if last_insert_ticks[bufnr] ~= vim.api.nvim_buf_get_changedtick(bufnr) then
			return
		end
		local row = vim.api.nvim_win_get_cursor(0)[1] - 1
		local first = vim.api.nvim_buf_set_extmark(bufnr, repeat_namespace, row, 0, { right_gravity = false })
		local last = vim.api.nvim_buf_set_extmark(
			bufnr,
			repeat_namespace,
			row,
			#vim.api.nvim_get_current_line(),
			{ right_gravity = true }
		)
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end
			local start = vim.api.nvim_buf_get_extmark_by_id(bufnr, repeat_namespace, first, {})
			local finish = vim.api.nvim_buf_get_extmark_by_id(bufnr, repeat_namespace, last, {})
			vim.api.nvim_buf_del_extmark(bufnr, repeat_namespace, first)
			vim.api.nvim_buf_del_extmark(bufnr, repeat_namespace, last)
			if vim.api.nvim_get_current_buf() ~= bufnr or #start == 0 or #finish == 0 or finish[1] <= start[1] then
				return
			end
			local after = finish[1] + 1
			for header_row = finish[1] + 1, start[1] + 1, -1 do
				local header = require("config.matlab.syntax").needs_end(bufnr, header_row)
				if header then
					local line = vim.api.nvim_buf_get_lines(bufnr, header.line - 1, header.line, false)[1]
					vim.cmd("undojoin")
					vim.api.nvim_buf_set_lines(bufnr, after, after, false, { line:match("^%s*") .. "end" })
					after = after + 1
				end
			end
			last_insert_ticks[bufnr] = vim.api.nvim_buf_get_changedtick(bufnr)
		end)
	end, repeat_namespace)
end

local function configure_buffer(bufnr)
	if not section_attached[bufnr] then
		section_attached[bufnr] = true
		vim.api.nvim_buf_attach(bufnr, false, {
			on_lines = function(_, _, _, first, last, new_last)
				local changed = section_changes[bufnr] or { first = first, last = new_last }
				if changed.lines then
					return
				end
				changed.first = math.min(changed.first, first)
				changed.last = math.max(changed.last, new_last)
				changed.lines = changed.lines or last ~= new_last
				section_changes[bufnr] = changed
			end,
			on_reload = function()
				section_changes[bufnr] = { lines = true }
			end,
			on_detach = function()
				section_changes[bufnr], section_attached[bufnr] = nil, nil
				section_rows[bufnr], section_line_counts[bufnr], current_sections[bufnr] = nil, nil, nil
			end,
		})
	end
	highlight_sections(bufnr)
	section_changes[bufnr] = nil
	if vim.api.nvim_get_current_buf() == bufnr then
		highlight_current_section(bufnr)
	end

	vim.keymap.set("i", "<CR>", function()
		return M.confirm_completion_or_newline()
	end, { buffer = bufnr, expr = true, replace_keycodes = true, desc = "Matlab newline and block end" })

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
	setup_insert_repeat()
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
			if normal_changed_section_boundaries(event.buf) then
				highlight_sections(event.buf)
			else
				current_sections[event.buf] = nil
			end
			section_changes[event.buf] = nil
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
			section_changes[event.buf] = nil
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
