describe("MATLAB per-client handlers", function()
	it("ignores runtime notifications from diagnostic and stale clients", function()
		local text_events = {}
		local workspace_events = {}
		local state_events = {}
		local prompt_events = {}
		local input_prompts = {}
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
		package.loaded["config.matlab.handler"] = nil
		local handlers = require("config.matlab.handler").handlers()

		handlers.text(nil, { text = "diagnostic", stream = 0 }, { client_id = 7 })
		handlers.mvmPromptChange(nil, { state = "READY", isIdle = true }, { client_id = 7 })
		handlers.mvmInputPrompt(nil, "Value: ", { client_id = 7 })
		handlers.WSBServerMessage(nil, { type = "Size" }, { client_id = 7 })
		handlers.mvmStateChange(nil, { state = "connected" }, { client_id = 7 })
		assert.same({}, text_events)
		assert.same({}, workspace_events)
		assert.same({}, state_events)
		assert.same({}, prompt_events)
		assert.same({}, input_prompts)

		handlers.text(nil, { text = "execution", stream = 1 }, { client_id = 42 })
		handlers.mvmPromptChange(nil, { state = "BUSY", isIdle = false }, { client_id = 42 })
		handlers.mvmInputPrompt(nil, "Value: ", { client_id = 42 })
		handlers.WSBServerMessage(nil, { type = "Size" }, { client_id = 42 })
		handlers.mvmStateChange(nil, { state = "connected" }, { client_id = 42 })
		assert.same({ { "execution", 1 } }, text_events)
		assert.same({ { "BUSY", false } }, prompt_events)
		assert.same({ "Value: " }, input_prompts)
		assert.are.equal(1, #workspace_events)
		assert.are.equal(42, workspace_events[1][2])
		assert.are.equal(1, #state_events)
		assert.are.equal(42, state_events[1][2])

		local ok, err = pcall(handlers.text, nil, {}, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("payload omitted text", err)

		ok, err = pcall(handlers.text, nil, { text = "bad" }, { client_id = 42 })
		assert.is_false(ok)
		assert.matches("payload omitted stream", err)

		package.loaded["config.matlab.core"] = nil
		package.loaded["config.matlab.command_window"] = nil
		package.loaded["config.matlab.workspace"] = nil
		package.loaded["config.matlab.handler"] = nil
	end)
end)
