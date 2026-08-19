describe("MATLAB execution client", function()
	local core
	local clients
	local sent
	local starts
	local stopped
	local next_client_id
	local roots

	local function add_client(id, notify_result)
		clients[id] = {
			id = id,
			name = "matlab_ls_exec",
			is_stopped = function()
				return false
			end,
			notify = function(_, method, params)
				table.insert(sent, { client_id = id, method = method, params = params })
				return notify_result ~= false
			end,
		}
	end

	before_each(function()
		package.loaded["config.matlab.core"] = nil
		roots = setmetatable({}, {
			__index = function()
				return "C:/repo-one"
			end,
		})
		package.loaded["config.matlab.lsp"] = {
			execution_root = function(bufnr)
				return roots[bufnr]
			end,
			exec_config = function(bufnr, handlers, on_exit)
				return {
					name = "matlab_ls_exec",
					root_dir = roots[bufnr],
					handlers = handlers,
					on_exit = on_exit,
				}
			end,
		}
		package.loaded["config.matlab.command_window"] = {
			handle_connection_state = function() end,
		}
		package.loaded["config.matlab.status"] = {
			update = function() end,
			blocked = function() end,
		}
		package.loaded["config.matlab.workspace"] = {
			on_connected = function() end,
			on_disconnected = function() end,
			on_eval_complete = function() end,
			handle_server_message = function() end,
		}

		clients = {}
		sent = {}
		starts = {}
		stopped = {}
		next_client_id = 41
		core = require("config.matlab.core")
		core._reset_for_tests()
		core.setup({
			connection_timeout_ms = 0,
			start_client = function(config, opts)
				local id = next_client_id
				next_client_id = next_client_id + 1
				add_client(id)
				table.insert(starts, { id = id, config = config, opts = opts })
				return id
			end,
			get_client = function(id)
				return clients[id]
			end,
			stop_client = function(id)
				table.insert(stopped, id)
				clients[id] = nil
			end,
		})
	end)

	after_each(function()
		core._reset_for_tests()
		package.loaded["config.matlab.status"] = nil
		package.loaded["config.matlab.workspace"] = nil
		package.loaded["config.matlab.command_window"] = nil
		package.loaded["config.matlab.lsp"] = nil
	end)

	it("queues commands while connecting and executes them one at a time", function()
		local completed = {}
		assert.is_true(core.enqueue_eval("first", {
			on_complete = function(ok)
				table.insert(completed, { "first", ok })
			end,
		}))
		assert.is_true(core.enqueue_eval("second", {
			on_complete = function(ok)
				table.insert(completed, { "second", ok })
			end,
		}))

		assert.are.equal("connecting", core._snapshot().state)
		assert.are.equal(2, core._snapshot().queue_length)
		assert.are.equal(0, #sent)
		assert.are.equal(false, starts[1].opts.attach)
		assert.are.equal("matlab_ls_exec", starts[1].config.name)

		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		assert.are.equal(1, #sent)
		assert.are.equal("first", sent[1].params.command)
		assert.are.equal(1, core._snapshot().queue_length)

		core.handle_eval_response({ requestId = sent[1].params.requestId }, 41)
		assert.are.equal(2, #sent)
		assert.are.equal("second", sent[2].params.command)
		assert.same({ { "first", true } }, completed)

		core.handle_eval_response({ requestId = sent[2].params.requestId }, 41)
		assert.is_nil(core._snapshot().inflight_request_id)
		assert.same({ { "first", true }, { "second", true } }, completed)
	end)

	it("ignores state and eval notifications from stale clients", function()
		core.enqueue_eval("first")
		core.handle_mvm_state_change({ state = "connected" }, 999)
		assert.are.equal("connecting", core._snapshot().state)
		assert.are.equal(0, #sent)

		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		core.handle_eval_response({ requestId = sent[1].params.requestId }, 999)
		assert.is_not_nil(core._snapshot().inflight_request_id)
	end)

	it("drops pending work on exit and creates a fresh client on the next command", function()
		local results = {}
		core.enqueue_eval("first", {
			on_complete = function(ok, err)
				table.insert(results, { ok, err })
			end,
		})
		core.enqueue_eval("second", {
			on_complete = function(ok, err)
				table.insert(results, { ok, err })
			end,
		})
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		core.handle_client_exit(41, 1, 0)

		assert.are.equal("disconnected", core._snapshot().state)
		assert.are.equal(2, #results)
		assert.is_false(results[1][1])
		assert.is_false(results[2][1])

		assert.is_true(core.enqueue_eval("third"))
		assert.are.equal(42, core._snapshot().client_id)
		assert.are.equal(2, #starts)
	end)

	it("treats a failed notification as a transport failure", function()
		core.enqueue_eval("first")
		clients[41].notify = function()
			return false
		end
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)

		assert.are.equal("disconnected", core._snapshot().state)
		assert.same({ 41 }, stopped)
	end)

	it("returns false when an evaluation cannot be sent immediately", function()
		core.ensure_client()
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		clients[41].notify = function()
			return false
		end

		local ok, err = core.enqueue_eval("first")
		assert.is_false(ok)
		assert.matches("failed to send", err)
		assert.are.equal("disconnected", core._snapshot().state)
	end)

	it("stops the execution client after a MATLAB disconnect notification", function()
		core.enqueue_eval("first")
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		core.handle_mvm_state_change({ state = "disconnected" }, 41)

		assert.are.equal("disconnected", core._snapshot().state)
		assert.same({ 41 }, stopped)
	end)

	it("keeps a replacement client when the old client exits late", function()
		core.ensure_client()
		core.handle_mvm_state_change({ state = "disconnected" }, 41)
		core.ensure_client()
		assert.are.equal(42, core._snapshot().client_id)

		core.handle_client_exit(41, 0, 0)
		assert.are.equal(42, core._snapshot().client_id)
		assert.are.equal("connecting", core._snapshot().state)
	end)

	it("allows a failure callback to queue work on a fresh client", function()
		local retry_ok = nil
		core.enqueue_eval("first", {
			on_complete = function(ok)
				if not ok then
					retry_ok = core.enqueue_eval("retry")
				end
			end,
		})
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		core.handle_mvm_state_change({ state = "disconnected" }, 41)

		assert.is_true(retry_ok)
		assert.are.equal(42, core._snapshot().client_id)
		assert.are.equal("connecting", core._snapshot().state)
		assert.are.equal(1, core._snapshot().queue_length)
	end)

	it("keeps the client created by a reentrant callback when the previous client disappears", function()
		core.enqueue_eval("first", {
			on_complete = function(ok)
				if not ok then
					core.enqueue_eval("retry")
				end
			end,
		})
		clients[41] = nil

		assert.is_true(core.enqueue_eval("second"))

		assert.are.equal(2, #starts)
		assert.are.equal(42, core._snapshot().client_id)
		assert.are.equal(2, core._snapshot().queue_length)
	end)

	it("resets a desynchronized client instead of leaving the execution queue stuck", function()
		local completed
		core.enqueue_eval("first", {
			on_complete = function(ok, err)
				completed = { ok, err }
			end,
		})
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)

		core.handle_eval_response({ requestId = "wrong-request" }, 41)

		assert.are.equal("disconnected", core._snapshot().state)
		assert.same({ 41 }, stopped)
		assert.is_false(completed[1])
		assert.matches("Mismatched evalResponse", completed[2])
		assert.is_true(core.enqueue_eval("retry"))
		assert.are.equal(42, core._snapshot().client_id)
	end)

	it("surfaces execution client startup exceptions after restoring disconnected state", function()
		core.setup({
			connection_timeout_ms = 0,
			start_client = function()
				error("broken start contract")
			end,
			get_client = function(id)
				return clients[id]
			end,
			stop_client = function(id)
				table.insert(stopped, id)
			end,
		})

		local ok, err = pcall(core.enqueue_eval, "first")
		assert.is_false(ok)
		assert.matches("broken start contract", err)
		assert.are.equal("disconnected", core._snapshot().state)
	end)

	it("routes document requests only to the attached diagnostic client", function()
		local requested = nil
		local diagnostic = {
			id = 7,
			name = "matlab_ls",
			request = function(_, method, params, _, bufnr)
				requested = { method = method, params = params, bufnr = bufnr }
				return true, 88
			end,
		}
		local original_get_clients = vim.lsp.get_clients
		vim.lsp.get_clients = function(filter)
			assert.are.equal("matlab_ls", filter.name)
			return { diagnostic }
		end

		local request_id, err = core.request_diagnostic(
			"textDocument/documentSymbol",
			{ test = true },
			function() end,
			3
		)
		vim.lsp.get_clients = original_get_clients

		assert.is_nil(err)
		assert.are.equal(88, request_id)
		assert.same({ method = "textDocument/documentSymbol", params = { test = true }, bufnr = 3 }, requested)
	end)

	it("keeps diagnostic requests independent while execution is in flight", function()
		assert.is_true(core.enqueue_eval("pause(10)"))
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		local inflight_request_id = core._snapshot().inflight_request_id
		assert.is_not_nil(inflight_request_id)

		local requested = nil
		local diagnostic = {
			id = 7,
			name = "matlab_ls",
			request = function(_, method, params, _, bufnr)
				requested = { method = method, params = params, bufnr = bufnr }
				return true, 89
			end,
		}
		local original_get_clients = vim.lsp.get_clients
		vim.lsp.get_clients = function(filter)
			assert.are.equal("matlab_ls", filter.name)
			assert.are.equal(3, filter.bufnr)
			return { diagnostic }
		end

		local request_id, err = core.request_diagnostic("textDocument/definition", { test = true }, function() end, 3)
		vim.lsp.get_clients = original_get_clients

		assert.is_nil(err)
		assert.are.equal(89, request_id)
		assert.same({ method = "textDocument/definition", params = { test = true }, bufnr = 3 }, requested)
		assert.are.equal(inflight_request_id, core._snapshot().inflight_request_id)
		assert.are.equal(1, #sent)
	end)

	it("tracks the session root and rejects explicit work from another project", function()
		roots[1] = "C:/repo-one"
		roots[2] = "C:/repo-two"
		assert.is_true(core.enqueue_eval("first", { bufnr = 1 }))
		assert.are.equal("C:/repo-one", core._snapshot().root_dir)

		local ok, err = core.enqueue_eval("wrong root", { bufnr = 2 })
		assert.is_false(ok)
		assert.matches("MatlabRestartHere", err)
		assert.are.equal(1, core._snapshot().queue_length)
		assert.are.equal(1, #starts)

		assert.is_true(core.enqueue_eval("internal"))
		assert.are.equal(2, core._snapshot().queue_length)
	end)

	it("reuses roots with Windows-equivalent casing and separators", function()
		roots[1] = "C:/Repo-One"
		roots[2] = "c:\\repo-one"
		assert.is_true(core.enqueue_eval("first", { bufnr = 1 }))
		assert.is_true(core.enqueue_eval("second", { bufnr = 2 }))
		assert.are.equal(1, #starts)
	end)

	it("cancels queued work without interrupting the active command", function()
		local completed = {}
		core.enqueue_eval("first", {
			on_complete = function(ok)
				table.insert(completed, { "first", ok })
			end,
		})
		core.enqueue_eval("second", {
			on_complete = function(ok)
				table.insert(completed, { "second", ok })
			end,
		})
		core.enqueue_eval("third", {
			on_complete = function(ok)
				table.insert(completed, { "third", ok })
			end,
		})
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)

		assert.are.equal(2, core.cancel_queued())
		assert.is_not_nil(core._snapshot().inflight_request_id)
		assert.are.equal(0, core._snapshot().queue_length)
		assert.same({ { "second", false }, { "third", false } }, completed)
	end)

	it("interrupts the active command without mutating its queue", function()
		core.enqueue_eval("first")
		core.enqueue_eval("second")
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)

		assert.is_true(core.interrupt())
		assert.are.equal("interruptRequest", sent[#sent].method)
		assert.are.equal(1, core._snapshot().queue_length)
		assert.is_not_nil(core._snapshot().inflight_request_id)
	end)

	it("stops the session and fails all pending work", function()
		local completed = {}
		core.enqueue_eval("first", {
			on_complete = function(ok)
				table.insert(completed, ok)
			end,
		})
		core.enqueue_eval("second", {
			on_complete = function(ok)
				table.insert(completed, ok)
			end,
		})
		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)

		assert.is_true(core.stop_session())
		assert.are.equal("disconnected", core._snapshot().state)
		assert.is_nil(core._snapshot().root_dir)
		assert.same({ 41 }, stopped)
		assert.same({ false, false }, completed)
	end)

	it("restarts the execution client in the requested project", function()
		roots[1] = "C:/repo-one"
		roots[2] = "C:/repo-two"
		core.ensure_client(1)

		assert.is_true(core.restart_here(2))
		assert.same({ 41 }, stopped)
		assert.are.equal(2, #starts)
		assert.are.equal(42, core._snapshot().client_id)
		assert.are.equal("C:/repo-two", core._snapshot().root_dir)
		assert.are.equal("connecting", core._snapshot().state)
	end)

	it("publishes connection state immediately and stops after unsubscribe", function()
		local events = {}
		local unsubscribe = core.subscribe_connection_state(function(state, opts)
			table.insert(events, { state = state, release = opts.release })
		end)

		assert.is_function(unsubscribe)
		assert.same({ { state = "disconnected" } }, events)

		assert.is_true(core.ensure_client(1))
		assert.same({
			{ state = "disconnected" },
			{ state = "connecting" },
		}, events)

		core.handle_mvm_state_change({ state = "connected", release = "R2024a" }, 41)
		assert.same({
			{ state = "disconnected" },
			{ state = "connecting" },
			{ state = "connected", release = "R2024a" },
		}, events)

		unsubscribe()
		core.handle_mvm_state_change({ state = "disconnected" }, 41)
		assert.are.equal(3, #events)
	end)
end)
