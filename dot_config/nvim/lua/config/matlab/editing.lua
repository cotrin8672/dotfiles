local M = {}

local group = vim.api.nvim_create_augroup("MatlabEditing", { clear = true })

local function rstrip(text)
	return (text:gsub("%s+$", ""))
end

local function lstrip(text)
	return (text:gsub("^%s+", ""))
end

local function indent_of(line)
	return line:match("^%s*") or ""
end

local function strip_line_continuation(line)
	return rstrip(line):gsub("%s*%.%.%.%s*%%?.*$", "")
end

local function has_line_continuation(line)
	return rstrip(line):find("%.%.%.%s*%%?.*$") ~= nil
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

local function continuation_block(row)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local start_row = row
	local end_row = row

	while start_row > 1 and has_line_continuation(lines[start_row - 1] or "") do
		start_row = start_row - 1
	end

	while end_row < #lines and has_line_continuation(lines[end_row] or "") do
		end_row = end_row + 1
	end

	return start_row, end_row, lines
end

local function join_continuation_block(start_row, end_row, lines)
	local base_indent = indent_of(lines[start_row] or "")
	local parts = {}

	for i = start_row, end_row do
		local part = strip_line_continuation(lines[i] or "")
		if i ~= start_row then
			part = lstrip(part)
		end
		if part ~= "" then
			table.insert(parts, part)
		end
	end

	local joined = base_indent .. table.concat(vim.tbl_map(vim.trim, parts), " ")
	vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, { joined })
	vim.api.nvim_win_set_cursor(0, { start_row, math.min(#joined, #base_indent) })
end

local function split_current_line(row, col, line)
	local left = rstrip(line:sub(1, col))
	local right = lstrip(line:sub(col + 1))

	if left == "" or right == "" or has_line_continuation(left) then
		return false
	end

	local indent = indent_of(line)
	local split_indent = indent .. string.rep(" ", vim.bo.shiftwidth)
	local first = left .. " ..."
	local second = split_indent .. right

	vim.api.nvim_buf_set_lines(0, row - 1, row, false, { first, second })
	vim.api.nvim_win_set_cursor(0, { row + 1, #split_indent })
	return true
end

function M.toggle_split_join()
	local row, col, line = line_parts_at_cursor()
	local start_row, end_row, lines = continuation_block(row)

	if start_row ~= end_row then
		join_continuation_block(start_row, end_row, lines)
		return
	end

	if not split_current_line(row, col, line) then
		vim.notify("Place the cursor at the Matlab split point", vim.log.levels.INFO)
	end
end

function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "matlab",
		callback = function(event)
			vim.keymap.set("i", "<CR>", function()
				return M.newline()
			end, { buffer = event.buf, expr = true, replace_keycodes = true, desc = "Matlab continuation newline" })

			vim.keymap.set("n", "<leader>s", M.toggle_split_join, {
				buffer = event.buf,
				desc = "Matlab split/join continuation",
			})
		end,
	})
end

return M
