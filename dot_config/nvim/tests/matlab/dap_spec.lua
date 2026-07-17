local dap_root = vim.fn.stdpath("data") .. "/lazy/nvim-dap"
vim.opt.runtimepath:append(dap_root)
package.path = table.concat({
	dap_root .. "/lua/?.lua",
	dap_root .. "/lua/?/init.lua",
	package.path,
}, ";")

local rpc = require("dap.rpc")

local function wait_for(predicate, message)
	assert(vim.wait(1000, predicate, 5), message or "timed out waiting for MATLAB DAP bridge")
end

local function encode_frame(message)
	return rpc.msg_with_content_length(vim.json.encode(message))
end

describe("MATLAB DAP bridge", function()
	local bridge
	local fake_dap
	local core
	local state
	local release
	local subscribers
	local notifications
	local ensured_buffers
	local blocked_messages
	local original_notify
	local unsubscribe_count
	local ensure_ok
	local ensure_error
	local notify_ok
	local notify_error
	local client

	local function emit_state(next_state, opts)
		state = next_state
		opts = opts or {}
		release = opts.release
		local listeners = vim.tbl_values(subscribers)
		for _, listener in ipairs(listeners) do
			listener(next_state, opts)
		end
	end

	local function resolve_adapter(config)
		local resolved = nil
		fake_dap.adapters.matlab(function(adapter)
			resolved = adapter
		end, config or { bufnr = 1 })
		return function()
			return resolved
		end
	end

	local function connect(adapter)
		local connected = false
		local connect_error = nil
		local eof = false
		local messages = {}
		client = assert(vim.uv.new_tcp(), "failed to create test TCP client")
		client:connect(adapter.host, adapter.port, function(err)
			connect_error = err
			connected = true
			if not err then
				client:read_start(rpc.create_read_loop(function(body)
					table.insert(messages, vim.json.decode(body))
				end, function()
					eof = true
				end))
			end
		end)
		wait_for(function()
			return connected
		end, "timed out connecting to MATLAB DAP test server")
		assert.is_nil(connect_error)
		return messages, function()
			return eof
		end
	end

	local function write(data)
		local completed = false
		local write_error = nil
		client:write(data, function(err)
			write_error = err
			completed = true
		end)
		wait_for(function()
			return completed
		end, "timed out writing a MATLAB DAP test message")
		assert.is_nil(write_error)
	end

	before_each(function()
		state = "disconnected"
		release = nil
		subscribers = {}
		notifications = {}
		ensured_buffers = {}
		blocked_messages = {}
		unsubscribe_count = 0
		ensure_ok = true
		ensure_error = nil
		notify_ok = true
		notify_error = nil
		client = nil

		local subscriber_id = 0
		core = {
			ensure_client = function(bufnr)
				table.insert(ensured_buffers, bufnr)
				if not ensure_ok then
					return false, ensure_error
				end
				if state == "disconnected" then
					emit_state("connecting")
				end
				return true, nil
			end,
			subscribe_connection_state = function(listener)
				subscriber_id = subscriber_id + 1
				local id = subscriber_id
				subscribers[id] = listener
				listener(state, { release = release })
				return function()
					if subscribers[id] then
						subscribers[id] = nil
						unsubscribe_count = unsubscribe_count + 1
					end
				end
			end,
			notify_exec = function(method, params)
				table.insert(notifications, { method = method, params = params })
				return notify_ok, notify_error
			end,
			is_exec_client = function(client_id)
				return client_id == 42
			end,
		}
		package.loaded["config.matlab.core"] = core
		original_notify = vim.notify
		vim.notify = function(message, level)
			table.insert(blocked_messages, { message = message, level = level })
		end
		package.loaded["config.matlab.dap"] = nil
		bridge = require("config.matlab.dap")
		bridge._reset_for_tests()
		fake_dap = { adapters = {}, configurations = {} }
		bridge.setup(fake_dap)
	end)

	after_each(function()
		bridge._reset_for_tests()
		if client and not client:is_closing() then
			client:read_stop()
			client:close()
		end
		package.loaded["config.matlab.dap"] = nil
		package.loaded["config.matlab.core"] = nil
		vim.notify = original_notify
	end)

	it("registers one launch configuration without adding policy to nvim-dap", function()
		assert.is_function(fake_dap.adapters.matlab)
		assert.same({
			{
				type = "matlab",
				request = "launch",
				name = "MATLAB: Connect debugger",
			},
		}, fake_dap.configurations.matlab)
	end)

	it("waits for the requested MATLAB root to connect before resolving", function()
		local get_adapter = resolve_adapter({ bufnr = 8 })
		assert.same({ 8 }, ensured_buffers)
		assert.is_nil(get_adapter())
		assert.are.equal(1, vim.tbl_count(subscribers))

		emit_state("connected", { release = "R2024a" })
		wait_for(function()
			return get_adapter() ~= nil
		end)
		assert.same({ type = "server", host = "127.0.0.1", port = get_adapter().port }, get_adapter())
		assert.is_number(get_adapter().port)
		assert.is_true(get_adapter().port > 0)
	end)

	it("cancels a pending adapter when MATLAB disconnects while connecting", function()
		local get_adapter = resolve_adapter({ bufnr = 8 })
		assert.is_nil(get_adapter())
		assert.are.equal(1, vim.tbl_count(subscribers))
		assert.is_true(bridge._snapshot().active)
		assert.is_false(bridge._snapshot().listening)

		emit_state("disconnected", { message = "MATLAB failed to connect" })

		assert.is_nil(get_adapter())
		assert.is_false(bridge._snapshot().active)
		assert.are.equal(1, unsubscribe_count)
		assert.are.equal(0, vim.tbl_count(subscribers))
	end)

	it("refuses a root mismatch without opening an adapter", function()
		ensure_ok = false
		ensure_error = "MATLAB session is rooted elsewhere; run :MatlabRestartHere"
		local get_adapter = resolve_adapter({ bufnr = 9 })

		assert.same({ 9 }, ensured_buffers)
		assert.is_nil(get_adapter())
		assert.same({ { message = ensure_error, level = vim.log.levels.ERROR } }, blocked_messages)
		assert.are.equal(0, vim.tbl_count(subscribers))
	end)

	it("frames requests and routes only matching responses and active-client events", function()
		state = "connected"
		release = "R2024a"
		local get_adapter = resolve_adapter({ bufnr = 3 })
		wait_for(function()
			return get_adapter() ~= nil
		end)
		local received = connect(get_adapter())

		local initialize = { seq = 1, type = "request", command = "initialize", arguments = {} }
		local threads = { seq = 2, type = "request", command = "threads" }
		local stack_trace = {
			seq = 3,
			type = "request",
			command = "stackTrace",
			arguments = { threadId = 1 },
		}
		local first_frame = encode_frame(initialize)
		local split_at = math.floor(#first_frame / 2)
		write(first_frame:sub(1, split_at))
		assert.are.equal(0, #notifications)
		write(first_frame:sub(split_at + 1) .. encode_frame(threads) .. encode_frame(stack_trace))
		wait_for(function()
			return #notifications == 3
		end)

		local session_id = notifications[1].params.tag
		assert.is_not_nil(session_id)
		assert.same({ initialize, threads, stack_trace }, {
			notifications[1].params.debugRequest,
			notifications[2].params.debugRequest,
			notifications[3].params.debugRequest,
		})
		for _, notification in ipairs(notifications) do
			assert.are.equal("DebugAdaptorRequest", notification.method)
			assert.are.equal(session_id, notification.params.tag)
		end

		local response = {
			seq = 10,
			type = "response",
			request_seq = 1,
			command = "initialize",
			success = true,
		}
		bridge.handle_response({ debugResponse = response, tag = "another-session" }, 42)
		vim.wait(20)
		assert.are.equal(0, #received)

		bridge.handle_response({ debugResponse = response, tag = session_id }, 99)
		bridge.handle_event({ debugEvent = { seq = 11, type = "event", event = "stopped" } }, 99)
		vim.wait(20)
		assert.are.equal(0, #received)

		local event = { seq = 11, type = "event", event = "stopped", body = { threadId = 1 } }
		bridge.handle_response({ debugResponse = response, tag = session_id }, 42)
		bridge.handle_event({ debugEvent = event }, 42)
		wait_for(function()
			return #received == 2
		end)
		assert.same({ response, event }, received)

		bridge.handle_debugging_state_change(true, 42)
		assert.is_true(bridge._snapshot().debugging)
		bridge.handle_debugging_state_change(false, 99)
		assert.is_true(bridge._snapshot().debugging)
	end)

	it("allows only one session and releases all resources on disconnect", function()
		state = "connected"
		release = "R2024a"
		local get_adapter = resolve_adapter({ bufnr = 1 })
		wait_for(function()
			return get_adapter() ~= nil
		end)
		local _, got_eof = connect(get_adapter())

		local get_second_adapter = resolve_adapter({ bufnr = 1 })
		assert.is_nil(get_second_adapter())
		assert.are.equal(1, #blocked_messages)
		assert.matches("already active", blocked_messages[1].message)
		assert.are.equal(vim.log.levels.ERROR, blocked_messages[1].level)

		emit_state("disconnected", { message = "MATLAB disconnected" })
		wait_for(got_eof, "active MATLAB DAP socket stayed open after disconnect")
		wait_for(function()
			return not bridge._snapshot().active
		end)
		assert.are.equal(1, unsubscribe_count)
		assert.are.equal(0, vim.tbl_count(subscribers))
	end)

	it("closes the session when forwarding a request fails", function()
		state = "connected"
		release = "R2024a"
		local get_adapter = resolve_adapter({ bufnr = 1 })
		wait_for(function()
			return get_adapter() ~= nil
		end)
		local _, got_eof = connect(get_adapter())
		notify_ok = false
		notify_error = "failed to notify matlab_ls_exec"

		write(encode_frame({ seq = 1, type = "request", command = "initialize" }))
		wait_for(function()
			return #notifications == 1
		end)
		wait_for(got_eof, "MATLAB DAP socket stayed open after notify failure")
		assert.is_false(bridge._snapshot().active)
		assert.are.equal(1, unsubscribe_count)
	end)
end)
