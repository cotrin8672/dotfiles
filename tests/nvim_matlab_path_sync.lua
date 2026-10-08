-- nvim --headless -u NONE -i NONE -n -l tests/nvim_matlab_path_sync.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
local timers, warnings, configs = {}, {}, {}
vim.defer_fn = function(callback, delay)
	timers[#timers + 1] = { callback = callback, delay = delay }
end
vim.notify = function(message)
	warnings[#warnings + 1] = message
end
vim.lsp.config = function(name, opts)
	configs[name] = opts
end
local function client(id, name, root)
	return {
		id = id,
		name = name,
		config = { root_dir = root },
		requests = {},
		notify = function(self, method, params)
			assert(method == "fevalRequest" and params.isUserEval == false)
			self.requests[#self.requests + 1] = params
			return true
		end,
	}
end
local runner = client(1, "matlab_ls_exec", "C:/project")
local other_runner = client(2, "matlab_ls_exec", "C:/other")
local diagnostic = client(3, "matlab_ls", "C:/project")
local other_diagnostic = client(4, "matlab_ls", "C:/other")
local active, busy, connected, subscriber = runner, false, true
package.loaded["config.matlab.core"] = {
	get_exec_client = function()
		return active
	end,
	is_active_exec_client = function(id)
		return active and active.id == id
	end,
	connection_state = function()
		return connected and "connected" or "disconnected"
	end,
	list_sessions = function()
		return { { current = true, busy = busy, root_dir = active.config.root_dir } }
	end,
	subscribe_connection_state = function(callback)
		subscriber = callback
		return function() end
	end,
}
vim.lsp.get_clients = function(filter)
	assert(filter.name == "matlab_ls")
	return { diagnostic, other_diagnostic }
end
local lsp = require("config.matlab.lsp")
lsp.setup({})
local function reply(c, request, value, error_message)
	return lsp.handle_path_response(nil, {
		requestId = request.requestId,
		result = error_message and { error = { msg = error_message } } or { result = value and { value } or {} },
	}, { client_id = c.id })
end
local function last(c)
	return assert(c.requests[#c.requests])
end
local function refresh(path)
	lsp.sync_path()
	local request = last(active)
	assert(request.functionName == "path" and request.nargout == 1 and #request.args == 0)
	assert(reply(active, request, path))
end

-- A diagnostic MATLAB starting later must eventually receive the runner path.
lsp.sync_path()
assert(#runner.requests == 0)
for _, c in ipairs({ diagnostic, other_diagnostic }) do
	configs.matlab_ls.handlers.mvmStateChange(nil, { state = "connected" }, { client_id = c.id })
end
timers[1].callback()
local reading = last(runner)
assert(not reply(other_runner, reading, "C:/wrong"), "ignore a response from the wrong MATLAB client")
lsp.sync_path()
assert(#runner.requests == 1, "coalesce runner path reads")
reply(runner, reading, "C:/toolbox")
assert(last(diagnostic).nargout == 1 and #other_diagnostic.requests == 0)
reply(diagnostic, last(diagnostic), "C:/toolbox")
assert(#diagnostic.requests == 1, "skip setting an unchanged path")
-- The coalesced refresh is pending after the first response.
reply(runner, last(runner), "C:/toolbox")
assert(#diagnostic.requests == 1)

refresh("C:/LLE/common;C:/second;C:/toolbox")
assert(last(diagnostic).nargout == 0)
assert(last(diagnostic).args[1] == "C:/LLE/common;C:/second;C:/toolbox", "preserve search-path order")
reply(diagnostic, last(diagnostic))
refresh("C:/second;C:/toolbox")
assert(last(diagnostic).args[1] == "C:/second;C:/toolbox", "preserve rmpath removals")
reply(diagnostic, last(diagnostic))
local before = #diagnostic.requests
refresh("C:/second;C:/toolbox")
assert(#diagnostic.requests == before, "do not repeat a path update")

busy = true
local reads_before = #runner.requests
lsp.sync_path()
assert(#runner.requests == reads_before, "do not query a busy runner")
busy = false
lsp.sync_path()
local stale = last(runner)
active = other_runner
reply(runner, stale, "C:/stale")
assert(#diagnostic.requests == before, "ignore a response from the formerly active session")
subscriber("connected")
vim.wait(10, function()
	return #other_runner.requests > 0
end)
reply(other_runner, last(other_runner), "C:/other-only")
assert(last(other_diagnostic).nargout == 1 and #diagnostic.requests == before)
reply(other_diagnostic, last(other_diagnostic), "C:/toolbox")
assert(last(other_diagnostic).args[1] == "C:/other-only", "update only the matching project")
reply(other_diagnostic, last(other_diagnostic))

active = runner
lsp.sync_path()
local timed_out = last(runner)
timers[#timers].callback()
assert(#warnings == 1 and warnings[1]:find("timed out"))
lsp.sync_path()
assert(last(runner).requestId ~= timed_out.requestId, "a timeout must allow a later refresh")
assert(not reply(runner, timed_out, "C:/late"), "ignore a late response after timeout")
reply(runner, last(runner), "C:/second;C:/toolbox")

lsp.sync_path()
local malformed = last(runner)
assert(lsp.handle_path_response(nil, { requestId = malformed.requestId, result = 42 }, { client_id = runner.id }))
assert(#warnings == 2 and warnings[2] == "Invalid MATLAB path response")
lsp.sync_path()
reply(runner, last(runner), nil, "MATLAB unavailable")
assert(#warnings == 3 and warnings[3] == "MATLAB unavailable")

local evaluations, passthrough = 0, 0
local exec = lsp.exec_config(0, {
	evalResponse = function()
		evaluations = evaluations + 1
		busy = false
	end,
	fevalResponse = function()
		passthrough = passthrough + 1
	end,
})
busy = true
reads_before = #runner.requests
exec.handlers.evalResponse(nil, {}, { client_id = runner.id })
assert(evaluations == 1 and #runner.requests == reads_before + 1, "refresh after the final runner evaluation")
exec.handlers.fevalResponse(nil, { requestId = "unrelated" }, { client_id = runner.id })
assert(passthrough == 1, "retain unrelated feval handlers")
reply(runner, last(runner), "C:/second;C:/toolbox")
connected = false
reads_before = #runner.requests
lsp.sync_path()
assert(#runner.requests == reads_before, "do not start or reconnect a runner for synchronization")
print("MATLAB path sync: active session, path order/removal, startup, busy, identity and timeout OK")
vim.cmd("qa!")
