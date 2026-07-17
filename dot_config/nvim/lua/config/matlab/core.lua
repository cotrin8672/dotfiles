local M = {}

local options = {}
local request_counter = 0
local connection_subscriber_counter = 0
local connection_subscribers = {}
local connection = {
	state = "disconnected",
	release = nil,
	client_id = nil,
	root_dir = nil,
	queue = {},
	inflight = nil,
	timer = nil,
}

local function status()
	return require("config.matlab.status")
end

local function workspace()
	return require("config.matlab.workspace")
end

local function default_options()
	return {
		connection_timeout_ms = 120000,
		start_client = function(config, start_opts)
			return vim.lsp.start(config, start_opts)
		end,
		get_client = function(client_id)
			return vim.lsp.get_client_by_id(client_id)
		end,
		stop_client = function(client_id)
			local client = vim.lsp.get_client_by_id(client_id)
			if client then
				client:stop(true)
			end
		end,
	}
end

local function client_is_active(client)
	return client and client.name == "matlab_ls_exec" and not client:is_stopped()
end

local function comparable_path(path)
	local normalized = vim.fs.normalize(path)
	if vim.fn.has("win32") == 1 then
		return normalized:lower()
	end
	return normalized
end

local function same_path(left, right)
	return comparable_path(left) == comparable_path(right)
end

local function clear_timer()
	if not connection.timer then
		return
	end

	connection.timer:stop()
	connection.timer:close()
	connection.timer = nil
end

local function complete_item(item, ok, result)
	if item and item.on_complete then
		item.on_complete(ok, result)
	end
end

local function take_work()
	local active = connection.inflight
	local queued = connection.queue
	connection.inflight = nil
	connection.queue = {}
	return active, queued
end

local function fail_work(active, queued, message)
	if active then
		complete_item(active, false, message .. "; the active command was not retried")
	end

	for _, item in ipairs(queued) do
		complete_item(item, false, message .. "; the queued command was not run")
	end
end

local function work_summary(message, active_count, queued_count)
	local details = {}
	if active_count > 0 then
		table.insert(details, "1 active command was not retried")
	end
	if queued_count > 0 then
		table.insert(
			details,
			("%d queued command%s were not run"):format(queued_count, queued_count == 1 and "" or "s")
		)
	end

	if #details == 0 then
		return message
	end
	return message .. " (" .. table.concat(details, "; ") .. ")"
end

local function set_connection_state(state, opts)
	opts = opts or {}
	connection.state = state
	connection.release = opts.release
	local subscribers = {}
	for _, subscriber in pairs(connection_subscribers) do
		table.insert(subscribers, subscriber)
	end
	for _, subscriber in ipairs(subscribers) do
		subscriber(state, opts)
	end
	local update = status().update
	local update_command_window = require("config.matlab.command_window").handle_connection_state
	vim.schedule(function()
		update(state, opts)
		update_command_window(state, opts)
	end)
end

local function reset_connection(message, client_id, stop_client, opts)
	opts = opts or {}
	if client_id and client_id ~= connection.client_id then
		return
	end

	local old_client_id = connection.client_id
	local active, queued = take_work()
	local active_count = active and 1 or 0
	local queued_count = #queued
	connection.client_id = nil
	connection.root_dir = nil
	clear_timer()
	local display_message = work_summary(message, active_count, queued_count)
	set_connection_state("disconnected", {
		message = display_message,
		level = opts.level or vim.log.levels.ERROR,
	})
	if stop_client and old_client_id then
		options.stop_client(old_client_id)
	end
	workspace().on_disconnected(opts.workspace_error == false and nil or message)
	fail_work(active, queued, message)
end

local function start_timeout(client_id)
	if options.connection_timeout_ms <= 0 then
		return
	end

	clear_timer()
	local timer = assert(vim.uv.new_timer(), "failed to create MATLAB connection timer")

	connection.timer = timer
	timer:start(
		options.connection_timeout_ms,
		0,
		vim.schedule_wrap(function()
			if connection.client_id == client_id and connection.state == "connecting" then
				reset_connection("Timed out while connecting to MATLAB", client_id, true)
			end
		end)
	)
end

local dispatch_next

function M.setup(user_opts)
	options = vim.tbl_deep_extend("force", default_options(), user_opts or {})
end

function M.is_exec_client(client_id)
	return client_id ~= nil and client_id == connection.client_id
end

function M.subscribe_connection_state(callback)
	assert(type(callback) == "function", "MATLAB connection state subscriber must be a function")
	connection_subscriber_counter = connection_subscriber_counter + 1
	local subscriber_id = connection_subscriber_counter
	connection_subscribers[subscriber_id] = callback
	callback(connection.state, { release = connection.release })

	return function()
		connection_subscribers[subscriber_id] = nil
	end
end

function M.get_exec_client()
	if not connection.client_id then
		return nil, "matlab_ls_exec client not found"
	end

	local client = options.get_client(connection.client_id)
	if not client_is_active(client) then
		return nil, "matlab_ls_exec client not found"
	end

	return client, nil
end

function M.ensure_client(bufnr)
	local requested_root = nil
	if bufnr ~= nil then
		requested_root = require("config.matlab.lsp").execution_root(bufnr)
	end

	if connection.client_id then
		local client = options.get_client(connection.client_id)
		if client_is_active(client) then
			assert(connection.root_dir, "active matlab_ls_exec client omitted its root directory")
			if requested_root and not same_path(requested_root, connection.root_dir) then
				return false,
					("MATLAB session is rooted at %s; run :MatlabRestartHere from %s to switch projects"):format(
						connection.root_dir,
						requested_root
					)
			end
			return true, nil
		end

		reset_connection("MATLAB execution client disappeared", connection.client_id, false)
		if connection.client_id then
			return true, nil
		end
	end

	set_connection_state("connecting")

	local handlers = require("config.matlab.handler").handlers()
	local config = require("config.matlab.lsp").exec_config(bufnr, handlers, function(code, signal, client_id)
		vim.schedule(function()
			M.handle_client_exit(client_id, code, signal)
		end)
	end)

	local started, client_id = xpcall(function()
		return options.start_client(config, {
			attach = false,
			bufnr = bufnr,
			silent = false,
			reuse_client = function()
				return false
			end,
		})
	end, debug.traceback)

	if not started then
		reset_connection("Failed to start matlab_ls_exec", nil, false)
		error(client_id, 0)
	end
	if not client_id then
		local message = "Failed to start matlab_ls_exec"
		reset_connection(message, nil, false)
		return false, message
	end

	connection.client_id = client_id
	connection.root_dir = config.root_dir
	start_timeout(client_id)
	return true, nil
end

dispatch_next = function()
	if connection.state ~= "connected" or connection.inflight or #connection.queue == 0 then
		return true, nil
	end

	local client, err = M.get_exec_client()
	if not client then
		reset_connection(err, connection.client_id, false)
		return false, err
	end

	local item = table.remove(connection.queue, 1)
	connection.inflight = item
	local sent = client:notify("evalRequest", {
		requestId = item.request_id,
		command = item.command,
		isUserEval = item.is_user_eval,
	})

	if not sent then
		reset_connection("Failed to send MATLAB evaluation", connection.client_id, true)
		return false, "failed to send MATLAB evaluation"
	end

	return true, nil
end

function M.enqueue_eval(command, opts)
	opts = opts or {}
	if type(command) ~= "string" or vim.trim(command) == "" then
		return false, "MATLAB command is empty"
	end

	local ok, err = M.ensure_client(opts.bufnr)
	if not ok then
		return false, err
	end

	local item = {
		request_id = M.new_request_id(),
		command = command,
		is_user_eval = opts.is_user_eval ~= false,
		on_complete = opts.on_complete,
	}
	table.insert(connection.queue, item)

	return dispatch_next()
end

function M.handle_eval_response(result, client_id)
	if not M.is_exec_client(client_id) then
		return
	end
	if type(result) ~= "table" or result.requestId == nil then
		reset_connection("Malformed evalResponse from matlab_ls_exec", client_id, true)
		return
	end
	if not connection.inflight then
		reset_connection("Unexpected evalResponse from matlab_ls_exec", client_id, true)
		return
	end

	if tostring(result.requestId) ~= tostring(connection.inflight.request_id) then
		reset_connection("Mismatched evalResponse from matlab_ls_exec", client_id, true)
		return
	end

	local item = connection.inflight
	connection.inflight = nil
	dispatch_next()
	complete_item(item, true, result)
	workspace().on_eval_complete()
end

function M.handle_mvm_state_change(result, client_id)
	if not M.is_exec_client(client_id) then
		return
	end
	if type(result) ~= "table" or type(result.state) ~= "string" then
		reset_connection("Malformed mvmStateChange from matlab_ls_exec", client_id, true)
		return
	end

	if result.state == "connected" then
		if type(result.release) ~= "string" or result.release == "" then
			reset_connection("Connected mvmStateChange omitted the MATLAB release", client_id, true)
			return
		end
		clear_timer()
		set_connection_state("connected", { release = result.release })
		local dispatched = dispatch_next()
		if dispatched then
			workspace().on_connected(result.release)
		end
	elseif result.state == "disconnected" then
		reset_connection("MATLAB disconnected", client_id, true)
	else
		reset_connection("Unknown MATLAB connection state: " .. result.state, client_id, true)
	end
end

function M.handle_launch_failed(client_id, message)
	if not M.is_exec_client(client_id) then
		return
	end

	assert(type(message) == "string" and message ~= "", "MATLAB launch failure omitted its message")
	reset_connection(message, client_id, true)
end

function M.handle_client_exit(client_id, code, signal)
	if not M.is_exec_client(client_id) then
		return
	end

	reset_connection(("MATLAB execution client exited (code %s, signal %s)"):format(code, signal), client_id, false)
end

function M.notify_exec(method, params)
	if connection.state ~= "connected" then
		return false, M.connection_error()
	end

	local client, err = M.get_exec_client()
	if not client then
		return false, err
	end

	if not client:notify(method, params or {}) then
		reset_connection("Failed to send " .. method .. " to MATLAB", connection.client_id, true)
		return false, "failed to notify matlab_ls_exec"
	end

	return true, nil
end

function M.interrupt()
	return M.notify_exec("interruptRequest", {})
end

function M.cancel_queued()
	local queued = connection.queue
	connection.queue = {}
	fail_work(nil, queued, "MATLAB command queue was cancelled")
	return #queued
end

function M.stop_session()
	if not connection.client_id then
		return false, "MATLAB is not connected"
	end

	reset_connection("MATLAB session stopped", connection.client_id, true, {
		level = vim.log.levels.INFO,
		workspace_error = false,
	})
	return true, nil
end

function M.restart_here(bufnr)
	if connection.client_id then
		reset_connection("MATLAB session restarted", connection.client_id, true, {
			level = vim.log.levels.INFO,
			workspace_error = false,
		})
	end
	return M.ensure_client(bufnr)
end

function M.connection_state()
	return connection.state, connection.release
end

function M.is_connected()
	return connection.state == "connected"
end

function M.connection_error()
	if connection.state == "connecting" then
		return "MATLAB is still connecting"
	end

	return "MATLAB is not connected"
end

function M.get_diagnostic_client(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ name = "matlab_ls", bufnr = bufnr })) do
		return client, nil
	end

	return nil, "matlab_ls diagnostic client not found"
end

function M.request_diagnostic(method, params, handler, bufnr)
	local client, err = M.get_diagnostic_client(bufnr)
	if not client then
		return nil, err
	end

	local ok, request_id = client:request(method, params or {}, handler, bufnr)
	if not ok then
		return nil, "failed to request " .. method .. " from matlab_ls"
	end

	return request_id, nil
end

function M.new_request_id()
	request_counter = request_counter + 1
	return ("%s-%d"):format(vim.uv.hrtime(), request_counter)
end

function M._snapshot()
	return {
		state = connection.state,
		release = connection.release,
		client_id = connection.client_id,
		root_dir = connection.root_dir,
		queue_length = #connection.queue,
		inflight_request_id = connection.inflight and connection.inflight.request_id or nil,
	}
end

function M._reset_for_tests()
	clear_timer()
	connection.state = "disconnected"
	connection.release = nil
	connection.client_id = nil
	connection.root_dir = nil
	connection.queue = {}
	connection.inflight = nil
	request_counter = 0
	connection_subscriber_counter = 0
	connection_subscribers = {}
	options = default_options()
end

M.setup()

return M
