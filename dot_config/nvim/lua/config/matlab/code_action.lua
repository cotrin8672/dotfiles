local M = {}
local resolve_method = "codeAction/resolve"

local function suppression_command(action)
	if type(action) ~= "table" or action.edit or action.disabled then
		return
	end
	local command = type(action.command) == "table" and action.command or action
	if command.command == "matlabls.lint.suppress.line" or command.command == "matlabls.lint.suppress.file" then
		return command
	end
end

local function edits_from_response(response)
	assert(type(response) == "table" and type(response.result) == "table", "Missing MATLAB suppression edits")
	local edits = response.result[1]
	-- getSuppressionEdits returns a cell vector with native TextEdit objects.
	if type(edits) == "table" and edits.mwtype == "cell" then
		edits = edits.mwdata
	end
	assert(type(edits) == "table" and vim.islist(edits), "Invalid MATLAB suppression edits")
	for _, edit in ipairs(edits) do
		assert(type(edit.newText) == "string" and type(edit.range) == "table", "Invalid MATLAB TextEdit")
		for _, edge in ipairs({ "start", "end" }) do
			local pos = edit.range[edge]
			assert(type(pos) == "table", "Missing MATLAB edit position")
			for _, field in ipairs({ "line", "character" }) do
				local number = pos[field]
				assert(type(number) == "number" and number >= 0 and number % 1 == 0, "Invalid MATLAB edit position")
			end
		end
		local first, last = edit.range.start, edit.range["end"]
		assert(
			last.line > first.line or (last.line == first.line and last.character >= first.character),
			"Invalid MATLAB edit range"
		)
	end
	return edits
end

function M.attach(client)
	if client.name ~= "matlab_ls" or client._matlab_code_action then
		return
	end
	client._matlab_code_action = true
	local request, supports, cancel = client.request, client.supports_method, client.cancel_request
	local response_handler = client.handlers.fevalResponse or vim.lsp.handlers.fevalResponse
	local pending, counter = {}, 0
	local function request_key(id)
		return ("matlab-code-action:%d:%d"):format(client.id, -id)
	end
	local function finish(key, err, action)
		local call = pending[key]
		if not call then
			return
		end
		pending[key] = nil
		vim.schedule(function()
			call.handler(err, action or call.action, {
				client_id = client.id,
				bufnr = call.bufnr,
				method = resolve_method,
				params = call.action,
			})
		end)
	end

	client.handlers.fevalResponse = function(err, result, ctx, config)
		local key = type(result) == "table" and result.requestId
		local call = pending[key]
		if not call or not ctx or ctx.client_id ~= client.id then
			if response_handler then
				return response_handler(err, result, ctx, config)
			end
			return
		end
		if err or (type(result.result) == "table" and result.result.error) then
			local failure = err or result.result.error
			local message = type(failure) == "table" and (failure.message or failure.msg) or tostring(failure)
			finish(key, { message = message or "MATLAB code action preview failed" })
			return
		end
		if
			not vim.api.nvim_buf_is_loaded(call.bufnr)
			or vim.api.nvim_buf_get_changedtick(call.bufnr) ~= call.version
			or vim.uri_from_bufnr(call.bufnr) ~= call.uri
		then
			finish(key, { message = "Source changed while resolving MATLAB code action" })
			return
		end
		local ok, edits = pcall(edits_from_response, result.result)
		if not ok then
			finish(key, { message = tostring(edits) })
			return
		end
		local action = vim.deepcopy(call.action)
		action.command = nil
		action.edit = {
			documentChanges = {
				{ textDocument = { uri = call.uri, version = call.version }, edits = edits },
			},
		}
		finish(key, nil, action)
	end

	client.supports_method = function(self, method, bufnr)
		if self ~= client then
			self, method, bufnr = client, self, method
		end
		return method == resolve_method or supports(self, method, bufnr)
	end
	client.cancel_request = function(self, id)
		if self ~= client then
			self, id = client, self
		end
		if id < 0 then
			pending[request_key(id)] = nil
			return true
		end
		return cancel(self, id)
	end
	client.request = function(self, method, action, handler, bufnr)
		if self ~= client then
			self, method, action, handler, bufnr = client, self, method, action, handler
		end
		if method ~= resolve_method then
			return request(self, method, action, handler, bufnr)
		end
		local command = suppression_command(action)
		if not command and supports(self, method, bufnr) then
			return request(self, method, action, handler, bufnr)
		end
		bufnr = bufnr and bufnr ~= 0 and bufnr or vim.api.nvim_get_current_buf()
		handler = handler or self.handlers[method] or vim.lsp.handlers[method]
		assert(type(handler) == "function", "Missing code action resolve handler")
		counter = counter + 1
		local id, key = -counter, request_key(-counter)
		pending[key] = { handler = handler, action = action, bufnr = bufnr }
		if not command then
			finish(key, nil, action)
			return true, id
		end
		local args = type(command.arguments) == "table" and command.arguments[1]
		if
			type(args) ~= "table"
			or type(args.id) ~= "string"
			or type(args.range) ~= "table"
			or type(args.range.start) ~= "table"
			or type(args.range.start.line) ~= "number"
			or args.range.start.line < 0
			or args.range.start.line % 1 ~= 0
			or not vim.api.nvim_buf_is_loaded(bufnr)
			or args.uri ~= vim.uri_from_bufnr(bufnr)
		then
			finish(key, { message = "Invalid MATLAB suppression command" })
			return true, id
		end
		pending[key].uri = args.uri
		pending[key].version = vim.api.nvim_buf_get_changedtick(bufnr)
		local sent = self:notify("fevalRequest", {
			requestId = key,
			functionName = "matlabls.handlers.linting.getSuppressionEdits",
			nargout = 1,
			args = {
				vim.lsp._buf_get_full_text(bufnr),
				args.id,
				args.range.start.line + 1,
				command.command == "matlabls.lint.suppress.file",
			},
			isUserEval = false,
		})
		if not sent then
			finish(key, { message = "Failed to request MATLAB code action preview" })
		else
			vim.defer_fn(function()
				finish(key, { message = "MATLAB code action preview timed out" })
			end, 10000)
		end
		return true, id
	end
end

return M
