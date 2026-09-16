local M = {}

local pending = {}
local cache = {}
local request_counter = 0

local function symbol_at_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local left = line:sub(1, col + 1):match("([%a_][%w_%.]*)$") or ""
	local right = line:sub(col + 2):match("^([%w_%.]*)") or ""
	local symbol = (left .. right):gsub("^%.*", ""):gsub("%.*$", "")
	return symbol ~= "" and symbol or nil
end

local function result_text(result)
	local value = result and result.result
	if type(value) == "table" and value.result ~= nil then
		value = value.result
	end
	if type(value) == "table" then
		value = value[1]
	end
	return type(value) == "string" and value or nil
end

local function show_help(symbol, text)
	local lines = vim.split(text:gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
	while lines[1] == "" do
		table.remove(lines, 1)
	end
	while lines[#lines] == "" do
		table.remove(lines)
	end
	vim.lsp.util.open_floating_preview(lines, "text", {
		border = "rounded",
		focus_id = "matlab_help",
		title = " MATLAB Help: " .. symbol .. " ",
		title_pos = "center",
	})
end

function M.hover(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local client, err = require("config.matlab.core").get_diagnostic_client(bufnr)
	if not client then
		vim.notify(err, vim.log.levels.WARN)
		return false
	end

	if client.server_capabilities and client.server_capabilities.hoverProvider then
		vim.lsp.buf.hover({ border = "rounded" })
		return true
	end

	local symbol = symbol_at_cursor()
	if not symbol then
		vim.notify("No MATLAB symbol under cursor", vim.log.levels.WARN)
		return false
	end

	local cache_key = ("%d\0%s"):format(client.id, symbol)
	if cache[cache_key] then
		show_help(symbol, cache[cache_key])
		return true
	end

	request_counter = request_counter + 1
	local request_id = ("matlab-help-%s-%d"):format(vim.uv.hrtime(), request_counter)
	pending[request_id] = { client_id = client.id, symbol = symbol, cache_key = cache_key }
	local sent = client:notify("fevalRequest", {
		requestId = request_id,
		functionName = "help",
		nargout = 1,
		args = { symbol },
		isUserEval = false,
	})
	if not sent then
		pending[request_id] = nil
		vim.notify("Failed to request MATLAB help", vim.log.levels.ERROR)
		return false
	end

	vim.defer_fn(function()
		if pending[request_id] then
			pending[request_id] = nil
			vim.notify("MATLAB help request timed out", vim.log.levels.WARN)
		end
	end, 10000)
	return true
end

function M.handle_response(_, result, ctx)
	if type(result) ~= "table" or result.requestId == nil then
		return
	end
	local request_id = tostring(result.requestId)
	local request = pending[request_id]
	if not request or not ctx or request.client_id ~= ctx.client_id then
		return
	end
	pending[request_id] = nil

	local text = result_text(result)
	if not text or vim.trim(text) == "" then
		vim.notify("No MATLAB help found for " .. request.symbol, vim.log.levels.WARN)
		return
	end
	cache[request.cache_key] = text
	show_help(request.symbol, text)
end

function M._reset_for_tests()
	pending = {}
	cache = {}
	request_counter = 0
end

return M
