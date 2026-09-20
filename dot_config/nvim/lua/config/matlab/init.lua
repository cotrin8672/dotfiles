local M = {}
local registered = false

local matlab_block_keywords = {
	arguments = true,
	classdef = true,
	enumeration = true,
	events = true,
	["for"] = true,
	["function"] = true,
	["if"] = true,
	methods = true,
	parfor = true,
	properties = true,
	spmd = true,
	switch = true,
	try = true,
	["while"] = true,
}

local matlab_dedent_keywords = {
	case = true,
	catch = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	otherwise = true,
}

local function strip_matlab_comment(line)
	local quote
	local index = 1
	while index <= #line do
		local character = line:sub(index, index)
		if quote then
			if character == quote then
				if line:sub(index + 1, index + 1) == quote then
					index = index + 1
				else
					quote = nil
				end
			end
		elseif character == "'" or character == '"' then
			quote = character
		elseif character == "%" then
			return line:sub(1, index - 1)
		end
		index = index + 1
	end
	return line
end

local function matlab_keyword(line)
	return vim.trim(strip_matlab_comment(line)):match("^(%a+)")
end

local function matlab_arguments_context(bufnr, lnum)
	local stack = {}
	local last_closed_arguments
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, lnum - 1, false)

	for line_number, line in ipairs(lines) do
		local code = vim.trim(strip_matlab_comment(line))
		local keyword = code:match("^(%a+)")
		if keyword == "end" then
			local block = table.remove(stack)
			if block and block.kind == "arguments" then
				last_closed_arguments = {
					line = line_number,
					indent = vim.fn.indent(line_number),
				}
			end
		elseif code ~= "" then
			last_closed_arguments = nil
			if matlab_block_keywords[keyword] then
				table.insert(stack, {
					kind = keyword,
					line = line_number,
				})
			end
		end
	end

	return stack, last_closed_arguments
end

function M.indent(lnum)
	local bufnr = vim.api.nvim_get_current_buf()
	local base_indent = 0
	if vim.fn.exists("*GetMatlabIndent") == 1 then
		local ok, result = pcall(vim.fn.GetMatlabIndent)
		if ok then
			base_indent = result
		end
	end

	local stack, last_closed_arguments = matlab_arguments_context(bufnr, lnum)
	local current_line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
	local current_keyword = matlab_keyword(current_line)
	local top = stack[#stack]
	if current_keyword == "end" and top then
		return vim.fn.indent(top.line)
	end
	if top and top.kind == "arguments" then
		return vim.fn.indent(top.line) + vim.fn.shiftwidth()
	end
	if
		last_closed_arguments
		and last_closed_arguments.line == lnum - 1
		and not matlab_dedent_keywords[current_keyword]
	then
		return last_closed_arguments.indent
	end

	return base_indent
end

local function setup_matlab_indent()
	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("MatlabIndent", { clear = true }),
		pattern = "matlab",
		callback = function(event)
			vim.schedule(function()
				if vim.api.nvim_buf_is_valid(event.buf) and vim.bo[event.buf].filetype == "matlab" then
					vim.bo[event.buf].indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
				end
			end)
		end,
	})
end

local function setup_auto_start(core)
	local requested_clients = {}

	local function request_start(client, bufnr)
		if not client or client.name ~= "matlab_ls" or requested_clients[client.id] then
			return
		end
		requested_clients[client.id] = true

		vim.defer_fn(function()
			if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "matlab" then
				return
			end

			local ok, err = core.ensure_client(bufnr)
			if not ok then
				require("config.matlab.status").blocked(err)
			end
		end, 500)
	end

	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("MatlabExecutionAutoStart", { clear = true }),
		callback = function(event)
			request_start(vim.lsp.get_client_by_id(event.data.client_id), event.buf)
		end,
	})

	for _, client in ipairs(vim.lsp.get_clients({ name = "matlab_ls" })) do
		for bufnr in pairs(client.attached_buffers or {}) do
			request_start(client, bufnr)
		end
	end
end

function M.setup()
	if registered then
		return
	end
	registered = true

	local core = require("config.matlab.core")
	local cmdwin = require("config.matlab.command_window")
	local exec = require("config.matlab.exec")

	setup_matlab_indent()
	core.setup({ connection_timeout_ms = 120000 })
	require("config.matlab.workspace").setup()
	require("config.matlab.editing").setup()
	require("config.matlab.commands")
	setup_auto_start(core)

	cmdwin.set_submit_callback(function(input, opts, session_id)
		if input ~= "" then
			return exec.eval(input, opts, session_id)
		end
		return true, nil
	end)

	cmdwin.set_interrupt_callback(function(session_id)
		exec.interrupt(session_id)
	end)

	vim.keymap.set("n", "<leader>mn", "<Cmd>MatlabNew<CR>", { desc = "Matlab new session" })
end

return M
