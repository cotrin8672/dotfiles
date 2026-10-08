-- Run: nvim --headless -u NONE -l tests/nvim_matlab_code_action.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.env.SUB_ACTION_ROOT or vim.fn.stdpath("data") .. "/lazy/sub-action.nvim")
local adapter = require("config.matlab.code_action")
local lsp = require("sub_action.lsp")
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/PreviewProbe.m")
vim.bo[buf].filetype = "matlab"
vim.bo[buf].fileformat = "unix"
vim.bo[buf].eol = true
local uri = vim.uri_from_bufnr(buf)
local source = { "% preview fixture", "foo=1;" }
local function reset_source()
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, source)
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
end
reset_source()

local notifications, requests, cancellations, delegated, executions, timeouts = {}, {}, {}, 0, 0, {}
local defer = vim.defer_fn
vim.defer_fn = function(callback, timeout)
	if timeout == 10000 then
		timeouts[#timeouts + 1] = callback
	else
		return defer(callback, timeout)
	end
end
local function make_client(name, native_resolve, id)
	return {
		name = name or "matlab_ls",
		id = id or 101,
		offset_encoding = "utf-16",
		commands = {},
		handlers = {
			fevalResponse = function()
				delegated = delegated + 1
			end,
		},
		supports_method = function(_, method)
			return method ~= "codeAction/resolve" or native_resolve == true
		end,
		request = function(_, method, params, handler)
			requests[#requests + 1] = method
			handler(nil, params)
			return true, #requests
		end,
		cancel_request = function(_, id)
			cancellations[#cancellations + 1] = id
			return true
		end,
		notify = function(_, method, params)
			assert(method == "fevalRequest", "Preview must never execute a command")
			notifications[#notifications + 1] = params
			return true
		end,
		exec_cmd = function()
			executions = executions + 1
		end,
	}
end
local client = make_client()
local other = make_client("matlab_ls_exec")
local untouched = other.request
adapter.attach(other)
assert(other.request == untouched, "Execution clients must remain unchanged")
adapter.attach(client)
local attached = client.request
adapter.attach(client)
assert(client.request == attached, "Attach must be idempotent")
assert(client:supports_method("codeAction/resolve", buf))
assert(client.supports_method("textDocument/completion", { bufnr = buf }), "Legacy calls must keep working")

local function action(file)
	return {
		title = file and "Suppress message NASGU in this file" or "Suppress message NASGU on this line",
		kind = "quickfix",
		command = {
			command = file and "matlabls.lint.suppress.file" or "matlabls.lint.suppress.line",
			arguments = { { id = "NASGU", uri = uri, range = { start = { line = 1, character = 0 } } } },
		},
	}
end
local edit =
	{ range = { start = { line = 1, character = 6 }, ["end"] = { line = 1, character = 6 } }, newText = " %#ok<NASGU>" }
local function respond(raw, call)
	call = call or notifications[#notifications]
	client.handlers.fevalResponse(
		nil,
		{ requestId = call.requestId, result = { result = { raw } } },
		{ client_id = client.id }
	)
end
local function wait_for(predicate)
	assert(vim.wait(1000, predicate, 1), "Asynchronous resolve did not complete")
end
local original = action()
local copy = vim.deepcopy(original)
local entry = { action = original, client = client }
local resolved, completed = nil, 0
lsp.resolve(entry, buf, function(result, err)
	assert(not err)
	resolved, completed = result, completed + 1
end)
lsp.resolve(entry, buf, function(result, err)
	assert(not err and result == resolved)
	completed = completed + 1
end)
assert(completed == 0 and #notifications == 1, "Resolve must be asynchronous and share one pending request")
local call = notifications[1]
assert(
	call.functionName == "matlabls.handlers.linting.getSuppressionEdits"
		and call.nargout == 1
		and call.isUserEval == false
)
assert(
	vim.deep_equal(call.args, { "% preview fixture\nfoo=1;\n", "NASGU", 2, false }),
	"Use the server's exact suppression arguments"
)
-- Observed MATLAB Language Server 1.3.12 wire format: a cell vector with native TextEdit objects.
respond({ mwsize = { 1, 1 }, mwtype = "cell", mwdata = { edit } }, call)
wait_for(function()
	return completed == 2
end)
assert(resolved.command == nil and vim.deep_equal(resolved.edit.documentChanges[1].edits, { edit }))
assert(resolved.edit.documentChanges[1].textDocument.version == vim.api.nvim_buf_get_changedtick(buf))
assert(vim.deep_equal(original, copy), "Resolution must preserve the received action")
local diff = lsp.preview(resolved.edit, client.offset_encoding)
assert(table.concat(diff, "\n"):find("+foo=1; %#ok<NASGU>", 1, true))
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), source), "Preview must leave source untouched")
local applied = false
-- Neovim's attached-buffer on_lines callback uses changedtick as the LSP version.
vim.lsp.util.buf_versions[buf] = vim.api.nvim_buf_get_changedtick(buf)
lsp.apply(entry, resolved, buf, function(err)
	assert(not err)
	applied = true
end)
assert(applied and executions == 0, "Confirmation must apply the edit once without executing the original command")
assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "foo=1; %#ok<NASGU>")
reset_source()

local file_result
vim.bo[buf].fileformat = "dos"
vim.bo[buf].eol = false
client:request("codeAction/resolve", action(true), function(err, result)
	assert(not err)
	file_result = result
end, buf)
assert(notifications[#notifications].args[4] == true, "File suppression must use the server's file flag")
assert(
	notifications[#notifications].args[1] == "% preview fixture\r\nfoo=1;",
	"Preserve CRLF and missing final newline"
)
local file_edit = vim.deepcopy(edit)
file_edit.newText = " %#ok<*NASGU>"
respond({ file_edit })
wait_for(function()
	return file_result ~= nil
end)
assert(table.concat(lsp.preview(file_result.edit, client.offset_encoding), "\n"):find("%#ok<*NASGU>", 1, true))
vim.bo[buf].fileformat = "unix"
vim.bo[buf].eol = true

local ordinary = { title = "Ordinary edit", edit = { changes = { [uri] = { edit } } } }
local returned
client.request("codeAction/resolve", ordinary, function(err, result)
	assert(not err)
	returned = result
end, buf)
wait_for(function()
	return returned ~= nil
end)
assert(returned == ordinary and #requests == 0, "Unsupported native resolve must retain ordinary actions")
client:request("textDocument/completion", {}, function() end, buf)
client.cancel_request(42)
assert(requests[1] == "textDocument/completion" and cancellations[1] == 42)
local native = make_client(nil, true, 102)
adapter.attach(native)
native:request("codeAction/resolve", ordinary, function() end, buf)
assert(requests[2] == "codeAction/resolve", "Native resolve support must remain available")
client.handlers.fevalResponse(
	nil,
	{ requestId = "matlab-help-probe", result = { result = { "help" } } },
	{ client_id = client.id }
)
assert(delegated == 1, "Help responses must reach the existing handler")

local callbacks = 0
local _, cancelled = client:request("codeAction/resolve", action(), function()
	callbacks = callbacks + 1
end, buf)
local cancelled_call = notifications[#notifications]
client:cancel_request(cancelled)
respond({ edit }, cancelled_call)
vim.wait(20, function()
	return false
end, 1)
assert(callbacks == 0 and #cancellations == 1, "Cancellation must only cancel the local preview")
local stale_error
client:request("codeAction/resolve", action(), function(err)
	stale_error = err
end, buf)
vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "% source changed" })
respond({ edit })
wait_for(function()
	return stale_error ~= nil
end)
assert(stale_error.message:find("Source changed", 1, true))
reset_source()
local invalid_error
client:request("codeAction/resolve", action(), function(err)
	invalid_error = err
end, buf)
respond({ { newText = "bad", range = { start = { line = -1, character = 0 }, ["end"] = { line = 0, character = 0 } } } })
wait_for(function()
	return invalid_error ~= nil
end)
local malformed = action()
malformed.command.arguments = false
local malformed_error, sent_count = nil, #notifications
client:request("codeAction/resolve", malformed, function(err)
	malformed_error = err
end, buf)
wait_for(function()
	return malformed_error ~= nil
end)
assert(#notifications == sent_count, "Malformed commands must fail before contacting MATLAB")
local matlab_error
client:request("codeAction/resolve", action(), function(err)
	matlab_error = err
end, buf)
client.handlers.fevalResponse(nil, {
	requestId = notifications[#notifications].requestId,
	result = { error = { msg = "MATLAB unavailable" } },
}, { client_id = client.id })
wait_for(function()
	return matlab_error ~= nil
end)
assert(matlab_error.message == "MATLAB unavailable")
local failed_client = make_client(nil, false, 103)
failed_client.notify = function()
	return false
end
adapter.attach(failed_client)
local send_error
failed_client:request("codeAction/resolve", action(), function(err)
	send_error = err
end, buf)
wait_for(function()
	return send_error ~= nil
end)
assert(send_error.message:find("Failed to request", 1, true))
local timeout_error
client:request("codeAction/resolve", action(), function(err)
	timeout_error = err
end, buf)
timeouts[#timeouts]()
wait_for(function()
	return timeout_error ~= nil
end)
assert(timeout_error.message:find("timed out", 1, true))

-- Exercise the installed asynchronous picker: Loading… must become a read-only diff.
local frames, picker_mappings = {}, nil
package.loaded["sub_action.ui"] = {
	menu = function() end,
	select = function() end,
	close = function() end,
	preview = function(_, lines)
		frames[#frames + 1] = lines
	end,
}
package.loaded["sub_action.lualine"] = {
	enter = function()
		return function() end
	end,
}
package.loaded["nvim-submode.runtime"] = {
	create = function(options)
		picker_mappings = options.mappings
		return { start = function() end, stop = function() end }
	end,
}
lsp.request = function(_, callback)
	callback({ { action = action(), client = client } })
	return function() end
end
require("sub_action").setup()
require("sub_action").open()
assert(frames[1][1] == "Loading…", "Picker must display pending resolution")
respond({ mwsize = { 1, 1 }, mwtype = "cell", mwdata = { edit } })
wait_for(function()
	return #frames >= 2
end)
assert(
	table.concat(frames[#frames], "\n"):find("+foo=1; %#ok<NASGU>", 1, true),
	"Picker must refresh after the response"
)
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), source))
vim.lsp.util.buf_versions[buf] = vim.api.nvim_buf_get_changedtick(buf)
for _, mapping in ipairs(picker_mappings) do
	if mapping.lhs == "<CR>" then
		mapping.action()
	end
end
vim.api.nvim_feedkeys("", "x", false)
assert(vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] == "foo=1; %#ok<NASGU>")
assert(executions == 0, "Picker confirmation must apply one edit without executing the suppression command")
require("sub_action").close()
vim.defer_fn = defer
print(
	"PASS: MATLAB suppression diffs, async picker, read-only preview, single apply, native delegation, cancellation and stale/error responses"
)
