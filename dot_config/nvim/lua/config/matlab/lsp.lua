local M = {}

local configured_capabilities = nil
local path_requests = {}
local path_reads = {}
local diagnostic_paths = {}
local diagnostic_ready = {}
local path_request_counter = 0
local unsubscribe_path_sync

local function same_root(left, right)
	if not left or not right then
		return false
	end
	left, right = vim.fs.normalize(left), vim.fs.normalize(right)
	if vim.fn.has("win32") == 1 then
		left, right = left:lower(), right:lower()
	end
	return left == right
end

local function request_feval(client, name, nargout, args, callback)
	path_request_counter = path_request_counter + 1
	local request_id = ("matlab-path-%s-%d"):format(vim.uv.hrtime(), path_request_counter)
	local request = { client_id = client.id, callback = callback }
	path_requests[request_id] = request
	local sent = client:notify("fevalRequest", {
		requestId = request_id,
		functionName = name,
		nargout = nargout,
		args = args,
		isUserEval = false,
	})
	if not sent then
		path_requests[request_id] = nil
		callback("Failed to request MATLAB path synchronization")
		return
	end
	vim.defer_fn(function()
		if path_requests[request_id] == request then
			path_requests[request_id] = nil
			callback("MATLAB path synchronization timed out")
		end
	end, 10000)
end

function M.handle_path_response(err, result, ctx)
	local request_id = type(result) == "table" and tostring(result.requestId) or nil
	local request = request_id and path_requests[request_id]
	if not request or not ctx or ctx.client_id ~= request.client_id then
		return false
	end
	path_requests[request_id] = nil
	local response = result.result
	local failure = err or (type(response) == "table" and response.error)
	if failure or type(response) ~= "table" then
		local message = type(failure) == "table" and (failure.message or failure.msg) or failure
		request.callback(tostring(message or "Invalid MATLAB path response"))
	else
		request.callback(nil, type(response.result) == "table" and response.result[1] or nil)
	end
	return true
end

local function current_runner(client_id)
	local core = require("config.matlab.core")
	return core.is_active_exec_client(client_id) and core.connection_state() == "connected"
end

local function synchronize_diagnostic(client, path, runner_id, root)
	if
		not current_runner(runner_id)
		or not same_root(root, client.config.root_dir)
		or not diagnostic_ready[client.id]
	then
		return
	end
	local state = diagnostic_paths[client.id] or {}
	diagnostic_paths[client.id] = state
	if state.pending then
		state.again = true
		return
	end
	if state.path == path then
		return
	end
	state.pending = true
	local function finish(err)
		state.pending = false
		if err then
			vim.notify(err, vim.log.levels.WARN)
		end
		if state.again then
			state.again = nil
			M.sync_path()
		end
	end
	local function apply()
		if
			not current_runner(runner_id)
			or not same_root(root, client.config.root_dir)
			or not diagnostic_ready[client.id]
		then
			finish()
			return
		end
		if state.path == path then
			finish()
			return
		end
		request_feval(client, "path", 0, { path }, function(err)
			if not err then
				state.path = path
			end
			finish(err)
		end)
	end
	if state.path == nil then
		request_feval(client, "path", 1, {}, function(err, value)
			if err or type(value) ~= "string" then
				finish(err or "Invalid MATLAB diagnostic path")
				return
			end
			state.path = value
			apply()
		end)
	else
		apply()
	end
end

function M.sync_path()
	local core = require("config.matlab.core")
	local runner = core.get_exec_client()
	if not runner or core.connection_state() ~= "connected" then
		return
	end
	local root
	for _, session in ipairs(core.list_sessions()) do
		if session.current then
			if session.busy then
				return
			end
			root = session.root_dir
			break
		end
	end
	local clients = vim.tbl_filter(function(client)
		return diagnostic_ready[client.id] and same_root(root, client.config.root_dir)
	end, vim.lsp.get_clients({ name = "matlab_ls" }))
	if #clients == 0 then
		return
	end
	if path_reads[runner.id] then
		path_reads[runner.id].again = true
		return
	end
	local reading = {}
	path_reads[runner.id] = reading
	request_feval(runner, "path", 1, {}, function(err, path)
		path_reads[runner.id] = nil
		if not current_runner(runner.id) then
			return
		end
		if err or type(path) ~= "string" then
			vim.notify(err or "Invalid MATLAB runner path", vim.log.levels.WARN)
			return
		end
		for _, client in ipairs(clients) do
			synchronize_diagnostic(client, path, runner.id, root)
		end
		if reading.again then
			M.sync_path()
		end
	end)
end

local function handle_diagnostic_state(_, result, ctx)
	if not ctx or type(result) ~= "table" then
		return
	end
	diagnostic_ready[ctx.client_id] = result.state == "connected"
	if not diagnostic_ready[ctx.client_id] then
		diagnostic_paths[ctx.client_id] = nil
	else
		vim.defer_fn(M.sync_path, 500)
	end
end

local function matlab_settings(connection_timing, index_workspace)
	local matlab_exe = vim.fn.exepath("matlab")
	local matlab_install_path = matlab_exe ~= "" and vim.fn.fnamemodify(matlab_exe, ":h:h") or ""

	return {
		MATLAB = {
			indexWorkspace = index_workspace,
			installPath = matlab_install_path,
			matlabConnectionTiming = connection_timing,
			telemetry = true,
		},
	}
end

function M.setup(capabilities)
	configured_capabilities = capabilities

	vim.lsp.config("matlab_ls", {
		capabilities = capabilities,
		settings = matlab_settings("onStart", true),
		on_init = function(client)
			require("config.matlab.code_action").attach(client)
		end,
		handlers = {
			fevalResponse = function(err, result, ctx)
				if not M.handle_path_response(err, result, ctx) then
					require("config.matlab.help").handle_response(err, result, ctx)
				end
			end,
			mvmStateChange = handle_diagnostic_state,
		},
	})
	if unsubscribe_path_sync then
		unsubscribe_path_sync()
	end
	unsubscribe_path_sync = require("config.matlab.core").subscribe_connection_state(function(state)
		if state == "connected" then
			vim.schedule(M.sync_path)
		end
	end)
	vim.api.nvim_create_autocmd("InsertEnter", {
		group = vim.api.nvim_create_augroup("MatlabCompletionPathSync", { clear = true }),
		callback = function(event)
			if vim.bo[event.buf].filetype == "matlab" then
				M.sync_path()
			end
		end,
	})
end

function M.execution_root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	return vim.fs.root(bufnr, ".git") or vim.fn.getcwd()
end

function M.exec_config(bufnr, handlers, on_exit)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local wrapped_handlers = vim.tbl_extend("force", {}, handlers, {
		fevalResponse = function(err, result, ctx)
			if not M.handle_path_response(err, result, ctx) and handlers.fevalResponse then
				handlers.fevalResponse(err, result, ctx)
			end
		end,
		evalResponse = function(err, result, ctx)
			if handlers.evalResponse then
				handlers.evalResponse(err, result, ctx)
			end
			if ctx and current_runner(ctx.client_id) then
				M.sync_path()
			end
		end,
	})

	return {
		name = "matlab_ls_exec",
		cmd = { "matlab-language-server", "--stdio" },
		root_dir = M.execution_root(bufnr),
		capabilities = configured_capabilities or vim.lsp.protocol.make_client_capabilities(),
		settings = matlab_settings("onStart", false),
		handlers = wrapped_handlers,
		on_exit = on_exit,
	}
end

return M
