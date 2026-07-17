describe("MATLAB per-client handlers", function()
	it("ignores runtime notifications from diagnostic and stale clients", function()
		local text_events = {}
		local workspace_events = {}
		local state_events = {}
		local prompt_events = {}
		local input_prompts = {}
		local debug_responses = {}
		local debug_events = {}
		local debugging_states = {}
		package.loaded["config.matlab.core"] = {
			is_exec_client = function(client_id)
				return client_id == 42
			end,
			handle_mvm_state_change = function(result, client_id)
				table.insert(state_events, { result, client_id })
			end,
		}
		package.loaded["config.matlab.command_window"] = {
			handle_text = function(text, stream)
				table.insert(text_events, { text, stream })
			end,
			handle_prompt_change = function(state, is_idle)
				table.insert(prompt_events, { state, is_idle })
			end,
			handle_input_prompt = function(prompt)
				table.insert(input_prompts, prompt)
			end,
		}
		package.loaded["config.matlab.workspace"] = {
			handle_server_message = function(result, client_id)
				table.insert(workspace_events, { result, client_id })
			end,
		}
		package.loaded["config.matlab.dap"] = {
			handle_response = function(result, client_id)
				table.insert(debug_responses, { result, client_id })
			end,
			handle_event = function(result, client_id)
				table.insert(debug_events, { result, client_id })
			end,
			handle_debugging_state_change = function(result, client_id)
				table.insert(debugging_states, { result, client_id })
			end,
		}
		package.loaded["config.matlab.handler"] = nil
		local handlers = require("config.matlab.handler").handlers()

		handlers.text(nil, { text = "diagnostic", stream = 0 }, { client_id = 7 })
		handlers.mvmPromptChange(nil, { state = "READY", isIdle = true }, { client_id = 7 })
		handlers.mvmInputPrompt(nil, "Value: ", { client_id = 7 })
		handlers.WSBServerMessage(nil, { type = "Size" }, { client_id = 7 })
		handlers.mvmStateChange(nil, { state = "connected" }, { client_id = 7 })
		handlers.DebugAdaptorResponse(nil, {}, { client_id = 7 })
		handlers.DebugAdaptorEvent(nil, {}, { client_id = 7 })
		handlers.DebuggingStateChange(nil, "invalid", { client_id = 7 })
		assert.same({}, text_events)
		assert.same({}, workspace_events)
		assert.same({}, state_events)
		assert.same({}, prompt_events)
		assert.same({}, input_prompts)
		assert.same({}, debug_responses)
		assert.same({}, debug_events)
		assert.same({}, debugging_states)

		handlers.text(nil, { text = "execution", stream = 1 }, { client_id = 42 })
		handlers.mvmPromptChange(nil, { state = "BUSY", isIdle = false }, { client_id = 42 })
		handlers.mvmInputPrompt(nil, "Value: ", { client_id = 42 })
		handlers.WSBServerMessage(nil, { type = "Size" }, { client_id = 42 })
		handlers.mvmStateChange(nil, { state = "connected" }, { client_id = 42 })
		local response = {
			debugResponse = { seq = 2, type = "response", request_seq = 1, command = "initialize", success = true },
			tag = 17,
		}
		local event = { debugEvent = { seq = 3, type = "event", event = "stopped" } }
		handlers.DebugAdaptorResponse(nil, response, { client_id = 42 })
		handlers.DebugAdaptorEvent(nil, event, { client_id = 42 })
		handlers.DebuggingStateChange(nil, true, { client_id = 42 })
		assert.same({ { "execution", 1 } }, text_events)
		assert.same({ { "BUSY", false } }, prompt_events)
		assert.same({ "Value: " }, input_prompts)
		assert.are.equal(1, #workspace_events)
		assert.are.equal(42, workspace_events[1][2])
		assert.are.equal(1, #state_events)
		assert.are.equal(42, state_events[1][2])
		assert.same({ { response, 42 } }, debug_responses)
		assert.same({ { event, 42 } }, debug_events)
		assert.same({ { true, 42 } }, debugging_states)

		local ok, err = pcall(handlers.text, nil, {}, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("payload omitted text", err)

		ok, err = pcall(handlers.text, nil, { text = "bad" }, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("payload omitted stream", err)

		ok, err = pcall(handlers.DebugAdaptorResponse, nil, { tag = 17 }, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("DebugAdaptorResponse payload omitted debugResponse", err)

		ok, err = pcall(handlers.DebugAdaptorResponse, nil, { debugResponse = {} }, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("DebugAdaptorResponse payload omitted tag", err)

		ok, err = pcall(handlers.DebugAdaptorResponse, nil, { debugResponse = "invalid", tag = 17 }, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("DebugAdaptorResponse debugResponse must be a table", err)

		ok, err = pcall(handlers.DebugAdaptorEvent, nil, {}, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("DebugAdaptorEvent payload omitted debugEvent", err)

		ok, err = pcall(handlers.DebugAdaptorEvent, nil, { debugEvent = "invalid" }, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("DebugAdaptorEvent debugEvent must be a table", err)

		ok, err = pcall(handlers.DebuggingStateChange, nil, "yes", { client_id = 42 })
		assert.is_false(ok)
		assert.matches("DebuggingStateChange payload must be a boolean", err)

		package.loaded["config.matlab.core"] = nil
		package.loaded["config.matlab.command_window"] = nil
		package.loaded["config.matlab.workspace"] = nil
		package.loaded["config.matlab.dap"] = nil
		package.loaded["config.matlab.handler"] = nil
	end)
end)
