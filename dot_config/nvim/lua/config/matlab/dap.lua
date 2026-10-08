local M = {}

local options = {}
local active_bridge = nil
local next_session_id = 0

local function core()
	return require("config.matlab.core")
end

local function default_options()
	return {
		new_tcp = function()
			return vim.uv.new_tcp()
		end,
		rpc = require("dap.rpc"),
		json_encode = vim.json.encode,
		json_decode = vim.json.decode,
		current_buf = vim.api.nvim_get_current_buf,
		notify = vim.notify,
	}
end

local function close_handle(handle, stop_reading)
	if not handle or handle:is_closing() then
		return
	end
	if stop_reading then
		handle:read_stop()
	end
	handle:close()
end

local function close_bridge(bridge)
	if bridge.closed then
		return
	end
	bridge.closed = true
	close_handle(bridge.socket, true)
	close_handle(bridge.server, false)
	bridge.socket = nil
	bridge.server = nil
	if bridge.unsubscribe then
		bridge.unsubscribe()
		bridge.unsubscribe = nil
	end
	if active_bridge == bridge then
		active_bridge = nil
	end
end

local function write_message(bridge, message)
	if bridge.closed or not bridge.socket then
		return
	end
	local body = options.json_encode(message)
	bridge.socket:write(options.rpc.msg_with_content_length(body))
end

local function handle_dap_request(bridge, body)
	local request = options.json_decode(body)
	assert(type(request) == "table", "MATLAB DAP request must be a table")
	assert(request.type == "request", "MATLAB DAP message must be a request")
	assert(type(request.seq) == "number", "MATLAB DAP request omitted its numeric seq")
	assert(type(request.command) == "string" and request.command ~= "", "MATLAB DAP request omitted its command")
	if request.command == "initialize" then
		bridge.started = true
	end

	local sent, err = core().notify_exec("DebugAdaptorRequest", {
		debugRequest = request,
		tag = bridge.session_id,
	})
	if not sent then
		close_bridge(bridge)
		options.notify(err, vim.log.levels.ERROR)
	end
end

local function accept_connection(bridge, err)
	if bridge.closed then
		return
	end
	if err then
		close_bridge(bridge)
		error(err)
	end

	local socket = assert(options.new_tcp(), "failed to create MATLAB DAP client socket")
	local accepted, accept_err = bridge.server:accept(socket)
	if not accepted then
		close_handle(socket, false)
		close_bridge(bridge)
		error(accept_err)
	end

	bridge.socket = socket
	close_handle(bridge.server, false)
	bridge.server = nil
	socket:read_start(options.rpc.create_read_loop(function(body)
		handle_dap_request(bridge, body)
	end, function()
		close_bridge(bridge)
	end))
end

local function open_server(bridge)
	if bridge.closed or bridge.server then
		return
	end

	local server = assert(options.new_tcp(), "failed to create MATLAB DAP server")
	bridge.server = server
	local bound, bind_err = server:bind("127.0.0.1", 0)
	if not bound then
		close_bridge(bridge)
		error(bind_err)
	end
	local listening, listen_err = server:listen(1, function(err)
		accept_connection(bridge, err)
	end)
	if not listening then
		close_bridge(bridge)
		error(listen_err)
	end

	local address = assert(server:getsockname(), "failed to resolve MATLAB DAP port")
	bridge.adapter_callback({
		type = "server",
		host = "127.0.0.1",
		port = address.port,
	})
end

local function start_bridge(adapter_callback, config)
	assert(type(config) == "table", "MATLAB DAP configuration must be a table")
	if active_bridge then
		options.notify("A MATLAB debugger session is already active", vim.log.levels.ERROR)
		return
	end

	next_session_id = next_session_id + 1
	local bridge = {
		session_id = next_session_id,
		adapter_callback = adapter_callback,
		closed = false,
		debugging = false,
		started = false,
	}
	active_bridge = bridge

	local ensured, err = core().ensure_client(config.bufnr or options.current_buf())
	if not ensured then
		close_bridge(bridge)
		options.notify(err, vim.log.levels.ERROR)
		return
	end

	bridge.unsubscribe = core().subscribe_connection_state(function(state)
		if state == "connected" then
			open_server(bridge)
		elseif state == "disconnected" then
			close_bridge(bridge)
		end
	end)
	if bridge.closed and bridge.unsubscribe then
		bridge.unsubscribe()
		bridge.unsubscribe = nil
	end
end

function M.setup(dap, user_opts)
	assert(type(dap) == "table", "nvim-dap instance must be a table")
	options = vim.tbl_deep_extend("force", default_options(), user_opts or {})
	dap.adapters.matlab = function(callback, config)
		start_bridge(callback, config)
	end

	dap.configurations.matlab = {
		{
			type = "matlab",
			request = "launch",
			name = "MATLAB: Connect debugger",
		},
	}
end

function M.handle_response(result, client_id)
	if not core().is_exec_client(client_id) then
		return
	end
	assert(type(result) == "table", "DebugAdaptorResponse payload must be a table")
	assert(result.tag ~= nil, "DebugAdaptorResponse payload omitted tag")
	assert(type(result.debugResponse) == "table", "DebugAdaptorResponse payload omitted debugResponse")
	if active_bridge and result.tag == active_bridge.session_id then
		write_message(active_bridge, result.debugResponse)
	end
end

function M.handle_event(result, client_id)
	if not core().is_exec_client(client_id) then
		return
	end
	assert(type(result) == "table", "DebugAdaptorEvent payload must be a table")
	assert(type(result.debugEvent) == "table", "DebugAdaptorEvent payload omitted debugEvent")
	if active_bridge and active_bridge.started then
		write_message(active_bridge, result.debugEvent)
		if result.debugEvent.event == "terminate" then
			active_bridge.started = false
		end
	end
end

function M.handle_debugging_state_change(result, client_id)
	if not core().is_exec_client(client_id) then
		return
	end
	assert(type(result) == "boolean", "DebuggingStateChange payload must be a boolean")
	if active_bridge then
		active_bridge.debugging = result
	end
end

function M._snapshot()
	if not active_bridge then
		return { active = false }
	end
	return {
		active = true,
		session_id = active_bridge.session_id,
		debugging = active_bridge.debugging,
		listening = active_bridge.server ~= nil,
		connected = active_bridge.socket ~= nil,
	}
end

function M._reset_for_tests()
	if active_bridge then
		close_bridge(active_bridge)
	end
	active_bridge = nil
	next_session_id = 0
	options = default_options()
end

return M
