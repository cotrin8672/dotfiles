local M = {}

local group = vim.api.nvim_create_augroup("MatlabEditing", { clear = true })

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

	vim.keymap.set("n", "<leader>mv", "<Cmd>MatlabWorkspace<CR>", {
		buffer = bufnr,
		desc = "Matlab toggle workspace",
	})
end

function M.setup()
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "matlab",
		callback = function(event)
			configure_buffer(event.buf)
		end,
	})

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype == "matlab" then
			configure_buffer(bufnr)
		end
	end
end

return M
