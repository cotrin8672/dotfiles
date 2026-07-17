local M = {}

local function from_exec_client(ctx)
	assert(ctx and ctx.client_id, "MATLAB LSP notification omitted ctx.client_id")
	return require("config.matlab.core").is_exec_client(ctx.client_id)
end

local function exec_payload(result, field, notification)
	assert(type(result) == "table", notification .. " payload must be a table")
	assert(result[field] ~= nil, notification .. " payload omitted " .. field)
	return result[field]
end

function M.handlers()
	return {
		text = function(_, result, ctx)
			if from_exec_client(ctx) then
				local text = exec_payload(result, "text", "text")
				local stream = exec_payload(result, "stream", "text")
				assert(type(text) == "string", "text payload field must be a string")
				assert(type(stream) == "number", "text payload stream must be a number")
				require("config.matlab.command_window").handle_text(text, stream)
			end
		end,
		clc = function(_, _, ctx)
			if from_exec_client(ctx) then
				require("config.matlab.command_window").handle_clc()
			end
		end,
		mvmPromptChange = function(_, result, ctx)
			if from_exec_client(ctx) then
				local state = exec_payload(result, "state", "mvmPromptChange")
				local is_idle = exec_payload(result, "isIdle", "mvmPromptChange")
				assert(type(state) == "string", "mvmPromptChange state must be a string")
				assert(type(is_idle) == "boolean", "mvmPromptChange isIdle must be a boolean")
				require("config.matlab.command_window").handle_prompt_change(state, is_idle)
			end
		end,
		mvmInputPrompt = function(_, result, ctx)
			if from_exec_client(ctx) then
				assert(type(result) == "string", "mvmInputPrompt payload must be a string")
				require("config.matlab.command_window").handle_input_prompt(result)
			end
		end,
		mvmStateChange = function(_, result, ctx)
			if from_exec_client(ctx) then
				require("config.matlab.core").handle_mvm_state_change(result, ctx.client_id)
			end
		end,
		evalResponse = function(_, result, ctx)
			if from_exec_client(ctx) then
				require("config.matlab.core").handle_eval_response(result, ctx.client_id)
			end
		end,
		WSBServerMessage = function(_, result, ctx)
			if from_exec_client(ctx) then
				require("config.matlab.workspace").handle_server_message(result, ctx.client_id)
			end
		end,
		DebugAdaptorResponse = function(_, result, ctx)
			if from_exec_client(ctx) then
				local response = exec_payload(result, "debugResponse", "DebugAdaptorResponse")
				exec_payload(result, "tag", "DebugAdaptorResponse")
				assert(type(response) == "table", "DebugAdaptorResponse debugResponse must be a table")
				require("config.matlab.dap").handle_response(result, ctx.client_id)
			end
		end,
		DebugAdaptorEvent = function(_, result, ctx)
			if from_exec_client(ctx) then
				local event = exec_payload(result, "debugEvent", "DebugAdaptorEvent")
				assert(type(event) == "table", "DebugAdaptorEvent debugEvent must be a table")
				require("config.matlab.dap").handle_event(result, ctx.client_id)
			end
		end,
		DebuggingStateChange = function(_, result, ctx)
			if from_exec_client(ctx) then
				assert(type(result) == "boolean", "DebuggingStateChange payload must be a boolean")
				require("config.matlab.dap").handle_debugging_state_change(result, ctx.client_id)
			end
		end,
		["matlab/launchfailed"] = function(_, _, ctx)
			if from_exec_client(ctx) then
				require("config.matlab.core").handle_launch_failed(ctx.client_id, "MATLAB failed to launch")
			end
		end,
		["feature/needsmatlab/nomatlab"] = function(_, _, ctx)
			if from_exec_client(ctx) then
				require("config.matlab.core").handle_launch_failed(ctx.client_id, "MATLAB is unavailable")
			end
		end,
	}
end

return M
