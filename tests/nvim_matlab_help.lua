-- nvim --headless -u NONE -i NONE -n -l tests/nvim_matlab_help.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
vim.o.columns, vim.o.lines = 120, 50
vim.cmd("syntax enable")
local help = require("config.matlab.help")
local timers, warnings, floats, count = {}, {}, {}, 0
vim.defer_fn = function(callback)
	timers[#timers + 1] = callback
end
vim.notify = function(message)
	warnings[#warnings + 1] = message
end
local open = vim.lsp.util.open_floating_preview
vim.lsp.util.open_floating_preview = function(lines, syntax, opts)
	local buf, win = open(lines, syntax, opts)
	floats[#floats + 1] = { lines = lines, buf = buf, win = win }
	return buf, win
end
local client = { id = 7, offset_encoding = "utf-16" }
package.loaded["config.matlab.core"] = {
	get_diagnostic_client = function()
		return client, "matlab_ls diagnostic client not found"
	end,
}
local origin
local function setup(caps, line)
	if origin and vim.api.nvim_win_is_valid(origin) then
		vim.api.nvim_set_current_win(origin)
	end
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_get_config(win).relative ~= "" then
			vim.api.nvim_win_close(win, true)
		end
	end
	help._reset_for_tests()
	timers, warnings, floats = {}, {}, {}
	client.server_capabilities, client.calls, client.rpc = caps or {}, {}, {}
	client.notify = function(self, method, params)
		assert(method == "fevalRequest" and params.nargout == 1 and params.isUserEval == false)
		self.calls[#self.calls + 1] = params
		return true
	end
	client.request = function(self, method, params, handler, bufnr)
		assert(bufnr == vim.api.nvim_get_current_buf())
		self.rpc[#self.rpc + 1] = { method = method, params = params, handler = handler }
		return true, #self.rpc
	end
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. ".m")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line or "runner = store.cached(@solve_lle, waveform);" })
	vim.bo[buf].filetype = "matlab"
	vim.api.nvim_win_set_cursor(0, { 1, 18 })
	origin = vim.api.nvim_get_current_win()
	return buf
end
local function call(name)
	for index = #client.calls, 1, -1 do
		if client.calls[index].functionName == name then
			return client.calls[index]
		end
	end
	error("No request for " .. name)
end
local function reply(name, text, shape, err)
	local value = shape == "direct" and { text } or { result = { text } }
	return help.handle_response(err, { requestId = call(name).requestId, result = value }, { client_id = client.id })
end
local cached = "C:/Users/minol/sakaue/LLE/common/+store/cached.m"
local function location(path, row)
	return { uri = vim.uri_from_fname(path), range = { start = { line = row or 0, character = 0 } } }
end
local function definition(result, err)
	assert(client.rpc[1].method == "textDocument/definition")
	client.rpc[1].handler(err, result)
end
local function content()
	return table.concat(assert(floats[#floats]).lines, "\n")
end
local function contains(text)
	assert(content():find(text, 1, true), "Missing " .. text .. " in " .. content())
end
local function passed()
	count = count + 1
end

-- The actual package function from the screenshot has a complete declaration.
local buf = setup({ definitionProvider = true })
assert(help.hover(buf))
assert(client.rpc[1].params.textDocument.uri == vim.uri_from_bufnr(buf))
assert(vim.deep_equal(client.rpc[1].params.position, { line = 0, character = 18 }))
assert(call("help").args[1] == "store.cached")
reply("help", "Cache the solver outputs using the committed Scheme's Keys and Values.")
assert(#floats == 0, "Await source information instead of displaying description only")
definition({ location(cached) })
contains("function runner = cached(solver, scheme)")
contains("arguments\n    solver (1, 1) function_handle\n    scheme (1, 1) store.Scheme\nend")
contains("Cache the solver outputs")
local float = floats[1]
assert(vim.api.nvim_win_get_config(float.win).title[1][1]:find("store.cached", 1, true))
assert(vim.api.nvim_win_get_height(float.win) >= 7, "Declaration and arguments must be visible")
assert(vim.bo[float.buf].filetype == "markdown")
local requests = #client.calls + #client.rpc
assert(help.hover(buf) and vim.api.nvim_get_current_win() == float.win, "Second K focuses the help for scrolling")
assert(#client.calls + #client.rpc == requests)
passed()

-- A LocationLink and direct feval return values are both supported.
setup({ definitionProvider = true })
help.hover()
definition({
	{
		targetUri = vim.uri_from_fname(cached),
		targetSelectionRange = { start = { line = 0, character = 18 } },
		targetRange = { start = { line = 0, character = 0 } },
	},
})
reply("help", "Package help", "direct")
contains("function runner = cached")
contains("Cache the solver outputs")
assert(not content():find("Package help", 1, true), "Use documentation from the resolved definition")
passed()

-- Servers without definition support resolve the current MATLAB search path.
setup()
help.hover()
reply("which", cached)
reply("help", "Fresh help")
contains("scheme (1, 1) store.Scheme")
passed()

-- If definition fails or has no readable M-file, which is the fallback.
for _, answer in ipairs({ {}, { location(cached .. ".missing") }, { uri = "untitled:test", range = {} } }) do
	setup({ definitionProvider = true })
	help.hover()
	definition(answer)
	reply("which", cached)
	reply("help", "Fallback help")
	contains("function runner = cached")
	passed()
end
setup({ definitionProvider = true })
help.hover()
definition(nil, { message = "definition unavailable" })
reply("which", cached)
reply("help", "Fallback help")
contains("function runner = cached")
passed()

-- Invalid optional server data cannot abort source/help fallback.
for _, answer in ipairs({
	{ 42 },
	{ uri = 42 },
	{ uri = vim.uri_from_fname(cached), range = 42 },
	{ uri = vim.uri_from_fname(cached), range = { start = 42 } },
}) do
	setup({ definitionProvider = true })
	help.hover()
	definition(answer)
	if #floats == 0 then
		reply("which", cached)
	end
	contains("function runner = cached")
	passed()
end

-- No fabricated declaration for built-ins, P-code, missing or unreadable files.
for _, path in ipairs({ "built-in (C:\\MATLAB\\toolbox\\matlab\\sin)", "C:/opaque.p", "", cached .. ".missing" }) do
	setup()
	help.hover()
	reply("which", path)
	reply("help", "\r\nBuiltin help\r\n\r\n")
	assert(content() == "Builtin help")
	assert(#warnings == 0)
	passed()
end

-- Missing help comments still allow the available source contract to be shown.
setup()
help.hover()
reply("which", cached)
reply("help", "")
contains("function runner = cached")
contains("Cache the solver outputs")
passed()

-- Loaded unsaved source wins over disk and stale MATLAB help comments.
local source = vim.api.nvim_create_buf(true, false)
local path = vim.fn.tempname() .. ".m"
vim.api.nvim_buf_set_name(source, path)
vim.api.nvim_buf_set_lines(source, 0, -1, false, {
	"function out = cached(solver, scheme, opts)",
	"% Unsaved description.",
	"arguments",
	"    solver function_handle",
	"    scheme store.Scheme",
	'    opts.Mode string = "fresh"',
	"end",
	"out = solver;",
	"end",
})
setup({ definitionProvider = true })
help.hover()
definition(location(path))
reply("help", "Stale description.")
contains("cached(solver, scheme, opts)")
contains('opts.Mode string = "fresh"')
contains("Unsaved description.")
assert(not content():find("Stale description", 1, true))
passed()

-- A later K rereads the definition rather than caching by symbol forever.
vim.api.nvim_win_close(floats[1].win, true)
vim.api.nvim_buf_set_lines(source, 0, 1, false, { "function out = cached(solver, scheme, opts, extra)" })
help.hover()
client.rpc[2].handler(nil, location(path))
reply("help", "Still stale")
contains("cached(solver, scheme, opts, extra)")
passed()

-- Windows definition URIs may use a lower-case drive even for an open C: buffer.
if vim.fn.has("win32") == 1 then
	setup({ definitionProvider = true })
	help.hover()
	definition(location(path:sub(1, 1):lower() .. path:sub(2)))
	reply("help", "Stale disk help")
	contains("cached(solver, scheme, opts, extra)")
	contains("Unsaved description.")
	passed()
end

-- A resolved local helper must not inherit help for a same-named path function.
local local_file = vim.api.nvim_create_buf(true, false)
local local_path = vim.fn.tempname() .. ".m"
vim.api.nvim_buf_set_name(local_file, local_path)
vim.api.nvim_buf_set_lines(local_file, 0, -1, false, {
	"function out = outer(x)",
	"out = helper(x);",
	"end",
	"function out = helper(value)",
	"% Correct local helper description.",
	"arguments",
	"    value double {mustBePositive}",
	"end",
	"out = value;",
	"end",
})
vim.bo[local_file].modified = false
setup({ definitionProvider = true }, "result = helper(1);")
vim.api.nvim_win_set_cursor(0, { 1, 11 })
help.hover()
reply("help", "GLOBAL helper documentation")
definition(location(local_path, 3))
contains("function out = helper(value)")
contains("Correct local helper description.")
assert(not content():find("GLOBAL helper", 1, true))
passed()

-- Wrong client, unrelated response, and repeated K cannot duplicate or corrupt a request.
setup()
help.hover()
local pending = call("help")
assert(help.hover() and #client.calls == 2)
assert(not help.handle_response(nil, { requestId = pending.requestId, result = { "Wrong" } }, { client_id = 99 }))
assert(
	not help.handle_response(nil, { requestId = "matlab-path-other", result = { "Wrong" } }, { client_id = client.id })
)
reply("which", cached)
reply("help", "Correct help")
contains("Cache the solver outputs")
assert(not content():find("Wrong", 1, true))
passed()

-- A reply after cursor movement, editing, changing buffers, or superseding K cannot open an old float.
for _, change in ipairs({
	function()
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	end,
	function()
		vim.api.nvim_buf_set_lines(0, 0, 1, false, { "other = store.cached();" })
	end,
	function()
		vim.api.nvim_set_current_buf(vim.api.nvim_create_buf(true, false))
	end,
}) do
	setup()
	help.hover()
	change()
	reply("which", cached)
	reply("help", "Old help")
	assert(#floats == 0 and #warnings == 0)
	passed()
end
setup()
help.hover()
local old = call("help")
vim.api.nvim_win_set_cursor(0, { 1, 30 })
help.hover()
assert(not help.handle_response(nil, { requestId = old.requestId, result = { "Old help" } }, { client_id = client.id }))
reply("which", "")
reply("help", "Current help")
assert(content() == "Current help")
passed()

-- Partial timeout keeps useful information and clears late replies for a retry.
setup()
help.hover()
reply("which", cached)
local late = call("help")
assert(#floats == 1, "Source and its comments should appear without waiting for MATLAB help")
timers[1]()
contains("function runner = cached")
assert(#warnings == 0)
assert(
	not help.handle_response(nil, { requestId = late.requestId, result = { "Late help" } }, { client_id = client.id })
)
passed()
setup()
help.hover()
reply("help", "Help is available")
timers[1]()
assert(content() == "Help is available" and #warnings == 0)
passed()
setup()
help.hover()
timers[1]()
assert(#floats == 0 and warnings[1]:find("timed out", 1, true))
help.hover()
reply("which", cached)
reply("help", "Retry succeeded")
contains("Cache the solver outputs")
passed()

-- MATLAB errors do not become documentation, but source information is retained.
setup()
help.hover()
reply("which", cached)
help.handle_response(nil, {
	requestId = call("help").requestId,
	result = { error = { msg = "not connected" } },
}, { client_id = client.id })
contains("scheme (1, 1) store.Scheme")
passed()
setup()
help.hover()
reply("which", "")
reply("help", "not documentation", nil, { message = "failed" })
assert(#floats == 0 and warnings[1]:find("No MATLAB help", 1, true))
passed()

-- A server with native hover keeps its documentation alongside the declaration.
setup({ definitionProvider = true, hoverProvider = true })
help.hover()
definition(location(cached))
assert(client.rpc[2].method == "textDocument/hover" and #client.calls == 0)
client.rpc[2].handler(nil, { contents = { kind = "markdown", value = "Native **documentation**" } })
contains("Native **documentation**")
contains("function runner = cached")
passed()
setup({ hoverProvider = true })
help.hover()
reply("which", cached)
client.rpc[1].handler(nil, nil)
reply("help", "Fallback from empty native hover")
contains("Cache the solver outputs")
passed()

for _, native in ipairs({
	42,
	{ contents = 42 },
	{ contents = {} },
	{ contents = { kind = "markdown", value = "  \n " } },
}) do
	setup({ hoverProvider = true })
	help.hover()
	reply("which", "")
	client.rpc[1].handler(nil, native)
	reply("help", "Help after invalid native hover")
	assert(content() == "Help after invalid native hover")
	passed()
end

-- A failed transport is handled, not leaked as an eternally pending request.
setup({ definitionProvider = true, hoverProvider = true })
client.request = function()
	return false
end
client.notify = function()
	return false
end
assert(help.hover())
assert(#floats == 0 and #warnings == 1)
timers[1]()
assert(#warnings == 1)
passed()

-- Bound larger contracts to a readable scrollable float, with every line retained.
setup()
help.hover()
reply("which", "")
local long = {}
for index = 1, 80 do
	long[index] = "line " .. index .. ": " .. string.rep("argument ", 30)
end
reply("help", table.concat(long, "\n"))
local last = floats[#floats]
assert(vim.api.nvim_win_get_height(last.win) <= math.floor(vim.o.lines * 0.65))
assert(vim.api.nvim_win_get_width(last.win) <= 100)
assert(vim.api.nvim_buf_line_count(last.buf) == 80)
passed()

print(("PASS: %d MATLAB hover scenarios (real floating previews, source, protocol and async UX)"):format(count))
vim.cmd("qa!")
