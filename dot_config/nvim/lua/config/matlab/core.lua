local M = {}

local options = {}
local request_counter = 0
local connection_subscriber_counter = 0
local connection_subscribers = {}
local sessions = {}
local active_index = nil
local next_session_id = 1

local function new_connection()
	local connection = {
		id = next_session_id,
		state = "disconnected",
		release = nil,
		client_id = nil,
		root_dir = nil,
		queue = {},
		inflight = nil,
		timer = nil,
	}
	next_session_id = next_session_id + 1
	return connection
end

local function active_connection()
	return active_index and sessions[active_index] or nil
end

local function connection_for_client(client_id)
	for index, connection in ipairs(sessions) do
		if connection.client_id == client_id then
			return connection, index
		end
	end
	return nil, nil
end

local function connection_for_session(session_id)
	for index, connection in ipairs(sessions) do
		if connection.id == session_id then
			return connection, index
		end
	end
	return nil, nil
end

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

local function clear_timer(connection)
	if not connection or not connection.timer then
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

local function take_work(connection)
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
		table.insert(details, ("%d queued command%s were not run"):format(queued_count, queued_count == 1 and "" or "s"))
	end
	return #details == 0 and message or message .. " (" .. table.concat(details, "; ") .. ")"
end

local function publish_active_state(connection, opts)
	if connection ~= active_connection() then
		return
	end
	opts = vim.tbl_extend("force", opts or {}, { release = connection.release })
	local subscribers = {}
	for _, subscriber in pairs(connection_subscribers) do
		table.insert(subscribers, subscriber)
	end
	for _, subscriber in ipairs(subscribers) do
		subscriber(connection.state, opts)
	end
	status().update(connection.state, opts)
end

local function select_command_window_session(connection)
	local select_session = require("config.matlab.command_window").select_session
	if select_session then
		select_session(connection.id, #sessions, active_index)
	end
end

local function remove_connection(connection)
	local removed_index = nil
	for index, candidate in ipairs(sessions) do
		if candidate == connection then
			removed_index = index
			break
		end
	end
	if not removed_index then
		return
	end

	local was_active = removed_index == active_index
	table.remove(sessions, removed_index)
	if #sessions == 0 then
		active_index = nil
		local cmdwin = require("config.matlab.command_window")
		if cmdwin.remove_session then
			cmdwin.remove_session(connection.id)
		end
		return
	end

	if was_active then
		active_index = math.min(removed_index, #sessions)
	elseif removed_index < active_index then
		active_index = active_index - 1
	end
	local selected = assert(active_connection())
	select_command_window_session(selected)
	if was_active then
		publish_active_state(selected)
		workspace().on_disconnected(nil)
		if selected.state == "connected" then
			workspace().on_connected(selected.release)
		end
	end
	local cmdwin = require("config.matlab.command_window")
	if cmdwin.remove_session then
		cmdwin.remove_session(connection.id)
	end
end

local function set_connection_state(connection, state, opts)
	opts = opts or {}
	connection.state = state
	connection.release = opts.release
	require("config.matlab.command_window").handle_connection_state(state, {
		release = opts.release,
		session_id = connection.id,
	})
	publish_active_state(connection, opts)
end

local function reset_connection(connection, message, client_id, stop_client, opts)
	opts = opts or {}
	if not connection or (client_id and client_id ~= connection.client_id) then
		return
	end
	local old_client_id = connection.client_id
	local active, queued = take_work(connection)
	connection.client_id = nil
	if opts.clear_root then
		connection.root_dir = nil
	end
	clear_timer(connection)
	set_connection_state(connection, "disconnected", {
		message = work_summary(message, active and 1 or 0, #queued),
		level = opts.level or vim.log.levels.ERROR,
	})
	if stop_client and old_client_id then
		options.stop_client(old_client_id)
	end
	if connection == active_connection() then
		workspace().on_disconnected(opts.workspace_error == false and nil or message)
	end
	fail_work(active, queued, message)
end

local function start_timeout(connection, client_id)
	if options.connection_timeout_ms <= 0 then
		return
	end
	clear_timer(connection)
	local timer = assert(vim.uv.new_timer(), "failed to create MATLAB connection timer")
	connection.timer = timer
	timer:start(options.connection_timeout_ms, 0, vim.schedule_wrap(function()
		if connection.client_id == client_id and connection.state == "connecting" then
			reset_connection(connection, "Timed out while connecting to MATLAB", client_id, true)
		end
	end))
end

local function ensure_active_session()
	local connection = active_connection()
	if connection then
		return connection
	end
	connection = new_connection()
	table.insert(sessions, connection)
	active_index = #sessions
	select_command_window_session(connection)
	return connection
end

local dispatch_next

function M.setup(user_opts)
	options = vim.tbl_deep_extend("force", default_options(), user_opts or {})
end

function M.is_exec_client(client_id)
	return connection_for_client(client_id) ~= nil
end

function M.is_active_exec_client(client_id)
	local connection = active_connection()
	return connection ~= nil and connection.client_id == client_id
end

function M.session_id_for_client(client_id)
	local connection = connection_for_client(client_id)
	return connection and connection.id or nil
end

function M.subscribe_connection_state(callback)
	assert(type(callback) == "function", "MATLAB connection state subscriber must be a function")
	connection_subscriber_counter = connection_subscriber_counter + 1
	local subscriber_id = connection_subscriber_counter
	connection_subscribers[subscriber_id] = callback
	local connection = active_connection()
	callback(connection and connection.state or "disconnected", { release = connection and connection.release or nil })
	return function()
		connection_subscribers[subscriber_id] = nil
	end
end

function M.get_exec_client()
	local connection = active_connection()
	if not connection or not connection.client_id then
		return nil, "matlab_ls_exec client not found"
	end
	local client = options.get_client(connection.client_id)
	if not client_is_active(client) then
		return nil, "matlab_ls_exec client not found"
	end
	return client, nil
end

local function ensure_connection_client(connection, bufnr)
	local requested_root = bufnr ~= nil and require("config.matlab.lsp").execution_root(bufnr) or nil
	if connection.client_id then
		local client = options.get_client(connection.client_id)
		if client_is_active(client) then
			assert(connection.root_dir, "active matlab_ls_exec client omitted its root directory")
			if requested_root and not same_path(requested_root, connection.root_dir) then
				return false, ("MATLAB session is rooted at %s; run :MatlabRestartHere from %s to switch projects"):format(connection.root_dir, requested_root)
			end
			return true, nil
		end
		reset_connection(connection, "MATLAB execution client disappeared", connection.client_id, false)
		if connection.client_id then
			return true, nil
		end
	end

	set_connection_state(connection, "connecting")
	local handlers = require("config.matlab.handler").handlers()
	local config = require("config.matlab.lsp").exec_config(bufnr, handlers, function(code, signal, client_id)
		vim.schedule(function()
			M.handle_client_exit(client_id, code, signal)
		end)
	end)
	if connection.root_dir and bufnr == nil then
		config.root_dir = connection.root_dir
	end

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
		reset_connection(connection, "Failed to start matlab_ls_exec", nil, false)
		error(client_id, 0)
	end
	if not client_id then
		local message = "Failed to start matlab_ls_exec"
		reset_connection(connection, message, nil, false)
		return false, message
	end
	connection.client_id = client_id
	connection.root_dir = config.root_dir
	start_timeout(connection, client_id)
	return true, nil
end

function M.ensure_client(bufnr)
	return ensure_connection_client(ensure_active_session(), bufnr)
end

dispatch_next = function(connection)
	if connection.state ~= "connected" or connection.inflight or #connection.queue == 0 then
		return true, nil
	end
	local client = options.get_client(connection.client_id)
	if not client_is_active(client) then
		local err = "matlab_ls_exec client not found"
		reset_connection(connection, err, connection.client_id, false)
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
		reset_connection(connection, "Failed to send MATLAB evaluation", connection.client_id, true)
		return false, "failed to send MATLAB evaluation"
	end
	return true, nil
end

function M.enqueue_eval(command, opts, session_id)
	opts = opts or {}
	if type(command) ~= "string" or vim.trim(command) == "" then
		return false, "MATLAB command is empty"
	end
	local connection
	if session_id ~= nil then
		connection = connection_for_session(session_id)
		-- The command window exists before its first execution client. Materialize
		-- its matching logical session on first submit without launching eagerly.
		if not connection and #sessions == 0 and session_id == next_session_id then
			connection = ensure_active_session()
		end
		if not connection then
			return false, "MATLAB session not found"
		end
		local ok, err = ensure_connection_client(connection, opts.bufnr)
		if not ok then
			return false, err
		end
	else
		local ok, err = M.ensure_client(opts.bufnr)
		if not ok then
			return false, err
		end
		connection = assert(active_connection())
	end
	table.insert(connection.queue, {
		request_id = M.new_request_id(),
		command = command,
		is_user_eval = opts.is_user_eval ~= false,
		on_complete = opts.on_complete,
	})
	return dispatch_next(connection)
end

function M.handle_eval_response(result, client_id)
	local connection = connection_for_client(client_id)
	if not connection then
		return
	end
	if type(result) ~= "table" or result.requestId == nil then
		reset_connection(connection, "Malformed evalResponse from matlab_ls_exec", client_id, true)
		return
	end
	if not connection.inflight then
		reset_connection(connection, "Unexpected evalResponse from matlab_ls_exec", client_id, true)
		return
	end
	if tostring(result.requestId) ~= tostring(connection.inflight.request_id) then
		reset_connection(connection, "Mismatched evalResponse from matlab_ls_exec", client_id, true)
		return
	end
	local item = connection.inflight
	connection.inflight = nil
	dispatch_next(connection)
	complete_item(item, true, result)
	if connection == active_connection() then
		workspace().on_eval_complete()
	end
end

function M.handle_mvm_state_change(result, client_id)
	local connection = connection_for_client(client_id)
	if not connection then
		return
	end
	if type(result) ~= "table" or type(result.state) ~= "string" then
		reset_connection(connection, "Malformed mvmStateChange from matlab_ls_exec", client_id, true)
		return
	end
	if result.state == "connected" then
		if type(result.release) ~= "string" or result.release == "" then
			reset_connection(connection, "Connected mvmStateChange omitted the MATLAB release", client_id, true)
			return
		end
		clear_timer(connection)
		set_connection_state(connection, "connected", { release = result.release })
		local dispatched = dispatch_next(connection)
		if dispatched and connection == active_connection() then
			workspace().on_connected(result.release)
		end
	elseif result.state == "disconnected" then
		reset_connection(connection, "MATLAB disconnected", client_id, true)
	else
		reset_connection(connection, "Unknown MATLAB connection state: " .. result.state, client_id, true)
	end
end

function M.handle_launch_failed(client_id, message)
	local connection = connection_for_client(client_id)
	if connection then
		assert(type(message) == "string" and message ~= "", "MATLAB launch failure omitted its message")
		reset_connection(connection, message, client_id, true)
	end
end

function M.handle_client_exit(client_id, code, signal)
	local connection = connection_for_client(client_id)
	if connection then
		reset_connection(connection, ("MATLAB execution client exited (code %s, signal %s)"):format(code, signal), client_id, false)
	end
end

function M.notify_exec(method, params, session_id)
	local connection = session_id ~= nil and connection_for_session(session_id) or active_connection()
	if not connection or connection.state ~= "connected" then
		return false, connection and connection.state == "connecting" and "MATLAB is still connecting"
			or "MATLAB is not connected"
	end
	local client = options.get_client(connection.client_id)
	if not client_is_active(client) then
		return false, "matlab_ls_exec client not found"
	end
	if not client:notify(method, params or {}) then
		reset_connection(connection, "Failed to send " .. method .. " to MATLAB", connection.client_id, true)
		return false, "failed to notify matlab_ls_exec"
	end
	return true, nil
end

function M.interrupt(session_id)
	return M.notify_exec("interruptRequest", {}, session_id)
end

function M.cancel_queued()
	local connection = active_connection()
	if not connection then
		return 0
	end
	local queued = connection.queue
	connection.queue = {}
	fail_work(nil, queued, "MATLAB command queue was cancelled")
	return #queued
end

function M.stop_session()
	local connection = active_connection()
	if not connection or not connection.client_id then
		return false, "MATLAB is not connected"
	end
	reset_connection(connection, "MATLAB session stopped", connection.client_id, true, {
		level = vim.log.levels.INFO,
		workspace_error = false,
		clear_root = true,
	})
	if not connection.client_id and #sessions > 1 then
		remove_connection(connection)
	end
	return true, nil
end

function M.restart_here(bufnr)
	local connection = active_connection()
	if connection and connection.client_id then
		reset_connection(connection, "MATLAB session restarted", connection.client_id, true, {
			level = vim.log.levels.INFO,
			workspace_error = false,
			clear_root = true,
		})
	end
	return M.ensure_client(bufnr)
end

local function select_index(index)
	if #sessions == 0 then
		return false, "No MATLAB sessions"
	end
	active_index = ((index - 1) % #sessions) + 1
	local connection = sessions[active_index]
	select_command_window_session(connection)
	publish_active_state(connection)
	workspace().on_disconnected(nil)
	if connection.state == "connected" then
		workspace().on_connected(connection.release)
	end
	return true, nil
end

function M.list_sessions()
	local result = {}
	for index, connection in ipairs(sessions) do
		result[index] = {
			id = connection.id,
			index = index,
			current = index == active_index,
			state = connection.state,
			release = connection.release,
			root_dir = connection.root_dir,
			queue_length = #connection.queue,
			busy = connection.inflight ~= nil,
		}
	end
	return result
end

function M.select_session(session_id)
	local _, index = connection_for_session(session_id)
	if not index then
		return false, "MATLAB session not found"
	end
	return select_index(index)
end

function M.new_session(bufnr)
	local previous = active_connection()
	if previous and not previous.client_id then
		return ensure_connection_client(previous, bufnr)
	end
	local connection = new_connection()
	if previous then
		connection.root_dir = previous.root_dir
	end
	table.insert(sessions, connection)
	active_index = #sessions
	select_command_window_session(connection)
	local ok, err = M.ensure_client(previous and nil or bufnr)
	if not ok then
		remove_connection(connection)
	end
	return ok, err
end

function M.next_session()
	return select_index((active_index or 0) + 1)
end

function M.previous_session()
	return select_index((active_index or 2) - 1)
end

function M.connection_state()
	local connection = active_connection()
	return connection and connection.state or "disconnected", connection and connection.release or nil
end

function M.is_connected()
	local connection = active_connection()
	return connection ~= nil and connection.state == "connected"
end

function M.connection_error()
	local connection = active_connection()
	if connection and connection.state == "connecting" then
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
	local connection = active_connection()
	return {
		state = connection and connection.state or "disconnected",
		release = connection and connection.release or nil,
		client_id = connection and connection.client_id or nil,
		root_dir = connection and connection.root_dir or nil,
		queue_length = connection and #connection.queue or 0,
		inflight_request_id = connection and connection.inflight and connection.inflight.request_id or nil,
		session_id = connection and connection.id or nil,
		session_index = active_index,
		session_count = #sessions,
	}
end

function M._reset_for_tests()
	for _, connection in ipairs(sessions) do
		clear_timer(connection)
	end
	sessions = {}
	active_index = nil
	next_session_id = 1
	request_counter = 0
	connection_subscriber_counter = 0
	connection_subscribers = {}
	options = default_options()
end

M.setup()

return M
