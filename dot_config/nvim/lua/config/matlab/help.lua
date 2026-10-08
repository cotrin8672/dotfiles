local M = {}

local pending = {}
local request_counter = 0
local active

local function symbol_at_cursor()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]
	local left = line:sub(1, col + 1):match("([%a_][%w_%.]*)$") or ""
	local right = line:sub(col + 2):match("^([%w_%.]*)") or ""
	local symbol = (left .. right):gsub("^%.*", ""):gsub("%.*$", "")
	return symbol ~= "" and symbol or nil
end

local function result_text(err, result)
	local value = result and result.result
	if err or (type(value) == "table" and value.error) then
		return nil
	end
	if type(value) == "table" and value.result ~= nil then
		value = value.result
	end
	if type(value) == "table" then
		value = value[1]
	end
	return type(value) == "string" and value or nil
end

local function text_lines(text)
	if not text or vim.trim(text) == "" then
		return {}
	end
	local lines = vim.split((text or ""):gsub("\r\n", "\n"):gsub("\r", "\n"), "\n", { plain = true })
	while lines[1] == "" do
		table.remove(lines, 1)
	end
	while lines[#lines] == "" do
		table.remove(lines)
	end
	return lines
end

local function source_info(symbol, path, row)
	if type(path) ~= "string" then
		return nil
	end
	-- which can append a local-function description to its file name.
	path = path:match("^(.-%.m)%s+%(") or path
	if not path:lower():match("%.m$") then
		return nil
	end
	local bufnr = vim.fn.bufnr(path)
	local lines
	if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
		lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	else
		local ok, contents = pcall(vim.fn.readfile, path)
		if not ok then
			return nil
		end
		lines = contents
	end
	local info = require("config.matlab.help_source").extract(table.concat(lines, "\n"), symbol, row)
	if info then
		info.modified = bufnr ~= -1 and vim.bo[bufnr].modified
	end
	return info
end

local function definition_info(symbol, result)
	if type(result) ~= "table" then
		return nil
	end
	local locations = (result.uri or result.targetUri) and { result } or result
	for _, location in ipairs(locations) do
		if type(location) == "table" then
			local uri = location.targetUri or location.uri
			local range = location.targetSelectionRange or location.targetRange or location.range
			local start = type(range) == "table" and range.start
			local row = type(start) == "table" and start.line or nil
			if type(uri) == "string" and uri:match("^file:") then
				local ok, path = pcall(vim.uri_to_fname, uri)
				local info = ok and source_info(symbol, path, row)
				if info then
					return info
				end
			end
		end
	end
end

local function current(request)
	return active == request
		and vim.api.nvim_win_is_valid(request.win)
		and vim.api.nvim_get_current_win() == request.win
		and vim.api.nvim_get_current_buf() == request.buf
		and vim.api.nvim_buf_get_changedtick(request.buf) == request.tick
		and vim.deep_equal(vim.api.nvim_win_get_cursor(request.win), request.cursor)
end

local function clear_pending(request)
	for id, call in pairs(pending) do
		if call.request == request then
			pending[id] = nil
		end
	end
end

local function finish(request)
	if request.finished or not request.source_done or not request.docs_done then
		return
	end
	request.finished = true
	clear_pending(request)
	if not current(request) then
		return
	end
	local info = request.info
	-- Source comments describe the resolved local/method definition; help(symbol)
	-- could instead describe a same-named function elsewhere on MATLAB's path.
	local docs = info and (not request.native_docs or info.modified) and info.help or request.docs or {}
	local lines = {}
	if info then
		table.insert(lines, "```matlab")
		vim.list_extend(lines, info.signature)
		if #info.arguments > 0 then
			table.insert(lines, "")
			vim.list_extend(lines, info.arguments)
		end
		table.insert(lines, "```")
	end
	if #docs > 0 then
		if #lines > 0 then
			table.insert(lines, "")
		end
		vim.list_extend(lines, docs)
	end
	if #lines == 0 then
		vim.notify(
			request.timed_out and "MATLAB help request timed out" or ("No MATLAB help found for " .. request.symbol),
			vim.log.levels.WARN
		)
		return
	end
	vim.lsp.util.open_floating_preview(lines, "markdown", {
		border = "rounded",
		focus_id = "matlab_help",
		title = " MATLAB Help: " .. request.symbol .. " ",
		title_pos = "center",
		max_width = math.max(1, math.min(100, vim.o.columns - 4)),
		max_height = math.max(1, math.floor(vim.o.lines * 0.65)),
	})
end

local function feval(request, name, callback)
	if request.finished then
		return
	end
	request_counter = request_counter + 1
	local request_id = ("matlab-help-%s-%d"):format(vim.uv.hrtime(), request_counter)
	pending[request_id] = { request = request, callback = callback }
	local sent = request.client:notify("fevalRequest", {
		requestId = request_id,
		functionName = name,
		nargout = 1,
		args = { request.symbol },
		isUserEval = false,
	})
	if not sent then
		pending[request_id] = nil
		callback(nil)
	end
end

function M.hover(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local preview = vim.b[bufnr].lsp_floating_preview
	if preview and vim.api.nvim_win_is_valid(preview) and vim.w[preview].matlab_help == bufnr then
		vim.api.nvim_set_current_win(preview)
		vim.cmd("stopinsert")
		return true
	end
	local client, err = require("config.matlab.core").get_diagnostic_client(bufnr)
	if not client then
		vim.notify(err, vim.log.levels.WARN)
		return false
	end
	local symbol = symbol_at_cursor()
	if not symbol then
		vim.notify("No MATLAB symbol under cursor", vim.log.levels.WARN)
		return false
	end
	if active and active.client.id == client.id and not active.finished and current(active) then
		return true
	end
	if active then
		clear_pending(active)
	end
	local request = {
		client = client,
		symbol = symbol,
		buf = bufnr,
		win = vim.api.nvim_get_current_win(),
		cursor = vim.api.nvim_win_get_cursor(0),
		tick = vim.api.nvim_buf_get_changedtick(bufnr),
	}
	active = request
	local params = vim.lsp.util.make_position_params(request.win, client.offset_encoding or "utf-16")
	local function resolved(info)
		request.info, request.source_done = info, true
		if info and not (client.server_capabilities and client.server_capabilities.hoverProvider) then
			request.docs_done = true
		end
		finish(request)
	end
	local function which()
		feval(request, "which", function(path)
			resolved(source_info(symbol, path))
		end)
	end
	if client.server_capabilities and client.server_capabilities.definitionProvider then
		local sent = client:request("textDocument/definition", params, function(def_err, result)
			if active ~= request or request.finished then
				return
			end
			request.info = not def_err and definition_info(symbol, result) or nil
			if request.info then
				resolved(request.info)
			else
				which()
			end
		end, bufnr)
		if not sent then
			which()
		end
	else
		which()
	end

	local function help()
		feval(request, "help", function(text)
			local lines = text_lines(text)
			request.docs = #lines > 0 and lines or nil
			request.docs_done = true
			finish(request)
		end)
	end
	if client.server_capabilities and client.server_capabilities.hoverProvider then
		local sent = client:request("textDocument/hover", params, function(hover_err, result)
			if active ~= request or request.finished then
				return
			end
			local contents = not hover_err and type(result) == "table" and result.contents
			local ok, lines = pcall(vim.lsp.util.convert_input_to_markdown_lines, contents)
			if ok and #lines > 0 and vim.trim(table.concat(lines, "\n")) ~= "" then
				request.docs, request.docs_done, request.native_docs = lines, true, true
				finish(request)
			else
				help()
			end
		end, bufnr)
		if not sent then
			help()
		end
	else
		help()
	end
	vim.defer_fn(function()
		if active == request and not request.finished then
			request.source_done, request.docs_done, request.timed_out = true, true, true
			finish(request)
		end
	end, 10000)
	return true
end

function M.handle_response(err, result, ctx)
	if type(result) ~= "table" or result.requestId == nil then
		return
	end
	local request_id = tostring(result.requestId)
	local call = pending[request_id]
	if not call or not ctx or call.request.client.id ~= ctx.client_id then
		return false
	end
	pending[request_id] = nil

	if active == call.request and not call.request.finished then
		call.callback(result_text(err, result))
	end
	return true
end

function M._reset_for_tests()
	pending = {}
	request_counter = 0
	active = nil
end

return M
