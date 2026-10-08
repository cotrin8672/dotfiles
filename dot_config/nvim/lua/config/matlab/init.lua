local M = {}
local registered = false

local matlab_dedent_keywords = {
	case = true,
	catch = true,
	["else"] = true,
	["elseif"] = true,
	["end"] = true,
	otherwise = true,
}

function M.indent(lnum)
	local bufnr = vim.api.nvim_get_current_buf()
	local syntax = require("config.matlab.syntax")
	local context = syntax.context(bufnr, lnum - 1)
	local top, last_closed_arguments = context.top, context.last_closed
	local current_line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
	local current_code = syntax.line(current_line, context.in_block_comment).code
	local current_keyword = syntax.keyword(current_code)
	local width = vim.fn.shiftwidth()
	if context.in_block_comment then
		return vim.fn.indent(lnum - 1)
	end
	if context.logical then
		local opener = context.logical.delimiter
		local indent = vim.fn.indent(opener and opener.line or context.logical.line)
		local close = current_code:match("^%s*([%)%]}])")
		local pairs = { [")"] = "(", ["]"] = "[", ["}"] = "{" }
		if close and opener and pairs[close] == opener.character then
			return indent
		end
		return indent + width
	end
	if current_keyword == "function" then
		local header = syntax.context(bufnr, lnum).header
		local parent = header and header.parent or syntax.function_parent(bufnr, lnum, top)
		return parent and (vim.fn.indent(parent.line) + width) or 0
	end
	if top and matlab_dedent_keywords[current_keyword] then
		local extra = (current_keyword == "case" or current_keyword == "otherwise") and width or 0
		return vim.fn.indent(top.line) + extra
	end
	if top then
		local extra = top.kind == "switch" and context.branch and context.branch.block == top and width or 0
		return vim.fn.indent(top.line) + width + extra
	end
	if current_keyword == "end" then
		return 0
	end
	if last_closed_arguments and last_closed_arguments.line == lnum - 1 then
		return vim.fn.indent(last_closed_arguments.line)
	end
	return 0
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
