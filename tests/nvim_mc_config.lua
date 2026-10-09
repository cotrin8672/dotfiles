-- Run from the repository root: nvim --headless -u NONE -l tests/nvim_mc_config.lua
-- Uses installed plugins, but never starts a language server or runs Gradle.
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
local lazy = vim.fn.stdpath("data") .. "/lazy"
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({
	"nvim-lint",
	"nvim-jdtls",
	"kross.nvim",
	"nvim-treesitter",
	"overseer.nvim",
	"conform.nvim",
	"guess-indent.nvim",
	"kotlin.nvim",
	"blink.cmp",
}) do
	vim.opt.rtp:append(lazy .. "/" .. plugin)
end
vim.opt.rtp:append(lazy .. "/mcdev-nvim/mcdev-nvim")
vim.g.mapleader = " "
local function spec(name)
	return dofile(config .. "/lua/plugins/" .. name .. ".lua")
end

local fixture = vim.fs.normalize(vim.fn.tempname())
local project = fixture .. "/project with spaces"
vim.fn.mkdir(project .. "/src/main/kotlin/example", "p")
vim.fn.writefile({}, project .. (vim.fn.has("win32") == 1 and "/gradlew.bat" or "/gradlew"))
vim.fn.writefile({}, project .. "/settings.gradle.kts")
local function buffer(path, ft, lines)
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_name(buf, project .. path)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
	vim.bo[buf].filetype = ft
	vim.api.nvim_set_current_buf(buf)
	return buf
end

require("shared.java_kotlin_package").setup()
local java = buffer("/src/main/java/example/Test.java", "java")
assert(vim.api.nvim_buf_get_lines(java, 0, 1, false)[1] == "package example;")
local kotlin = buffer("/src/main/kotlin/example/Test.kt", "kotlin")
assert(vim.api.nvim_buf_get_lines(kotlin, 0, 1, false)[1] == "package example")
local existing = buffer("/src/main/java/example/Existing.java", "java", { "", "// existing content" })
assert(vim.api.nvim_buf_get_lines(existing, 0, 1, false)[1] == "")

package.loaded["config.matlab.toolchain"] = { clang_include_flag = function() end }
spec("nvim-lint").config()
local lint = require("lint")
assert(lint.linters_by_ft.java == nil)
local lint_calls = {}
assert(lint.linters_by_ft.kotlin == nil, "Kotlin must not mix IntelliJ formatting with automatic ktlint diagnostics")
lint.try_lint = function()
	lint_calls[#lint_calls + 1] = vim.api.nvim_get_current_buf()
end
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = kotlin })
assert(#lint_calls == 0, "Kotlin must not start ktlint on InsertLeave")
local done = require("config.lint").format_started(kotlin)
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = kotlin })
vim.wait(10, function()
	return false
end)
assert(#lint_calls == 0, "Lint must wait for formatting")
vim.b[kotlin].conform_applying_formatting = true
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = kotlin })
vim.b[kotlin].conform_applying_formatting = nil
done()
assert(vim.wait(100, function()
	return #lint_calls == 1
end))
assert(lint_calls[1] == kotlin, "Lint must use the saved buffer, not the current one")
vim.api.nvim_exec_autocmds("InsertLeave", { buffer = existing })
assert(#lint_calls == 2, "Other filetypes retain InsertLeave lint")
vim.api.nvim_buf_call(kotlin, function()
	assert(lint.linters.ktlint.args[3]() == "--stdin-path=" .. vim.api.nvim_buf_get_name(kotlin))
end)

local provider = require("overseer.template.gradle")
local templates
provider.generator({ dir = project .. "/src/main/kotlin" }, function(value)
	templates = value
end)
assert(templates and #templates == 1)
local task_config = templates[1].builder({ task = "runClient" })
assert(task_config.cwd == project and task_config.cmd[2] == "runClient")
if vim.fn.has("win32") == 1 then
	assert(
		task_config.strategy.wrap_opts.pty == false,
		"Windows Gradle output must use pipes without losing terminal input"
	)
else
	assert(task_config.strategy == nil, "Other platforms retain the default terminal strategy")
end
assert(task_config.cmd[1]:find("project with spaces", 1, true), "Wrapper path must remain one argument")
local prefix = vim.fn.has("win32") == 1 and "C:/work/" or "/work/"
local parser = task_config.components[1].parser
for _, line in ipairs({
	"e: " .. vim.uri_from_fname(prefix .. "日本語 with spaces/Drill.kt") .. ":90:34 Unresolved reference 'bad'.",
	prefix .. "Mixin.java:12: error: cannot find symbol",
	"w: " .. vim.uri_from_fname(prefix .. "literal%20name.kt") .. ":3:4 Warning",
	"e: " .. prefix .. "literal%20name.kt:5:6 Plain path must not be URI-decoded",
	"src/main/kotlin/example/Relative.kt:8: error: relative path",
}) do
	parser:parse(line)
end
local qf = parser:get_result().diagnostics
assert(#qf == 5 and qf[1].valid == 1 and qf[1].lnum == 90 and qf[1].col == 34)
assert(qf[2].valid == 1 and qf[2].lnum == 12)
assert(vim.fs.normalize(vim.api.nvim_buf_get_name(qf[1].bufnr)) == prefix .. "日本語 with spaces/Drill.kt")
assert(qf[3].type == "W" and qf[3].col == 4)
assert(vim.fs.normalize(vim.api.nvim_buf_get_name(qf[3].bufnr)) == prefix .. "literal%20name.kt")
assert(vim.fs.normalize(vim.api.nvim_buf_get_name(qf[4].bufnr)) == prefix .. "literal%20name.kt")
assert(vim.fs.normalize(vim.api.nvim_buf_get_name(qf[5].bufnr)) == project .. "/src/main/kotlin/example/Relative.kt")
local other_parser = templates[1].builder({ task = "classes" }).components[1].parser
other_parser:parse(prefix .. "Other.java:7: error: isolated task")
assert(#parser:get_result().diagnostics == 5 and #other_parser:get_result().diagnostics == 1)
parser:reset()
parser:parse(prefix .. "AfterRestart.java:2: error: restarted task")
assert(#parser:get_result().diagnostics == 1, "Restart must clear pending multiline compiler output")
local unique = task_config.components[3]
assert(unique.replace == false and unique.restart_interrupts == false)
assert(not unique.compare({ name = "classes", cwd = "one" }, { name = "classes", cwd = "two" }))
local overseer = require("overseer")
overseer.setup(spec("overseer").opts)
local task, discovery_error
overseer.run_task({
	name = "Gradle wrapper",
	search_params = { dir = project .. "/src/main/kotlin" },
	params = { task = "classes" },
	autostart = false,
}, function(value, err)
	task, discovery_error = value, err
end)
assert(
	vim.wait(3000, function()
		return task ~= nil or discovery_error ~= nil
	end),
	"Task discovery timed out"
)
assert(task, discovery_error or "Overseer must discover and validate the Gradle template")
task:dispose(true)

local mcdev_spec = spec("mc-dev")
require("mcdev.config").setup(mcdev_spec.opts({ dir = lazy .. "/mcdev-nvim" }))
assert(require("mcdev.config").options.navigation.enable == false)
spec("kross").config(nil, spec("kross").opts)

-- Use the real LSP lifecycle/reuse logic, replacing only the external server process.
local rpc_start, kross_attach = vim.lsp.rpc.start, require("kross").attach
local starts, kross_clients = {}, {}
require("kross").attach = function(client)
	kross_clients[client.id] = true
end
vim.lsp.rpc.start = function(_, dispatchers)
	local state = { notifications = {} }
	starts[#starts + 1] = state
	local closing, request_id = false, 0
	return {
		request = function(method, params, callback, on_reply)
			request_id = request_id + 1
			local id = request_id
			if method == "initialize" then
				state.initialize = params
			end
			vim.schedule(function()
				if on_reply then
					on_reply(id)
				end
				callback(nil, method == "initialize" and {
					capabilities = {
						textDocumentSync = 2,
						semanticTokensProvider = {
							legend = { tokenTypes = { "class" }, tokenModifiers = {} },
							full = true,
						},
					},
				} or {})
			end)
			return true, id
		end,
		notify = function(method, params)
			state.notifications[#state.notifications + 1] = { method = method, params = params }
			return true
		end,
		is_closing = function()
			return closing
		end,
		terminate = function()
			closing = true
			vim.schedule(function()
				dispatchers.on_exit(0, 0)
			end)
		end,
	}
end
vim.api.nvim_set_current_buf(kotlin)
assert(vim.tbl_contains(spec("jdtls").ft, "kotlin"), "Kotlin must load JDTLS and its MC/kross dependencies")
spec("jdtls").config()
vim.api.nvim_exec_autocmds("FileType", { buffer = kotlin })
assert(#starts == 1, "Kotlin must start one workspace, including repeated events before initialization")
assert(vim.wait(1000, function()
	return #vim.lsp.get_clients({ name = "jdtls" }) == 1
end))
local workspace = vim.lsp.get_clients({ name = "jdtls" })[1]
assert(kross_clients[workspace.id], "Kotlin-first startup must initialize kross")
assert(not workspace.attached_buffers[kotlin], "JDTLS must not analyze Kotlin documents")
for _, scratch in ipairs({ vim.api.nvim_create_buf(true, false), vim.api.nvim_create_buf(false, true) }) do
	vim.api.nvim_set_current_buf(scratch)
	vim.bo[scratch].filetype = "java"
	assert(#starts == 1 and not workspace.attached_buffers[scratch], "JDTLS must not open unnamed or scratch documents")
end
vim.api.nvim_set_current_buf(kotlin)
assert(vim.fn.filereadable(vim.api.nvim_buf_get_name(kotlin)) == 0, "Kotlin startup must not save the buffer")
assert(
	require("mcdev.protocol").active_jdtls_client(kotlin) == workspace,
	"MC requests must find the detached workspace"
)
local initialization = starts[1].initialize.initializationOptions
assert(workspace.config.settings.java.signatureHelp.enabled)
assert(
	initialization.extendedClientCapabilities.classFileContentsSupport,
	"Later Java buffers need decompilation support"
)
assert(vim.tbl_contains(initialization.bundles, require("mcdev.jdtls").resolve_extension_jar()))
for _, jar in ipairs(require("kross").bundles()) do
	assert(vim.tbl_contains(initialization.bundles, jar))
end
buffer("/build.gradle.kts", "kotlin")
assert(#starts == 1, "Another Kotlin buffer must reuse the workspace")
if vim.fn.has("win32") == 1 then
	local case_buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_buf_set_name(case_buf, project:lower() .. "/src/main/kotlin/example/Case.kt")
	vim.api.nvim_set_current_buf(case_buf)
	vim.bo[case_buf].filetype = "kotlin"
	assert(#starts == 1, "Kotlin LSP's lowercase Windows drive URI must reuse the JDTLS workspace")
end
vim.fn.mkdir(project .. "/src/main/java/example", "p")
vim.fn.writefile(vim.api.nvim_buf_get_lines(java, 0, -1, false), vim.api.nvim_buf_get_name(java))
vim.api.nvim_set_current_buf(java)
vim.api.nvim_exec_autocmds("FileType", { buffer = java })
assert(#starts == 1 and workspace.attached_buffers[java], "Java must attach to the Kotlin-started workspace")
assert(not vim.lsp.semantic_tokens.get_at_pos(java, 0, 0), "Java must not start JDTLS semantic highlighting")
vim.api.nvim_buf_set_lines(java, 0, -1, false, { "package example;", "class Test { } // 日本語" })
assert(
	vim.wait(1000, function()
		for _, notification in ipairs(starts[1].notifications) do
			if notification.method == "textDocument/didChange" then
				local changes = notification.params.contentChanges
				assert(#changes == 1 and changes[1].range == nil, "JDTLS edits must send the complete document")
				assert(
					changes[1].text:gsub("\r\n", "\n") == "package example;\nclass Test { } // 日本語\n",
					vim.inspect(changes)
				)
				return true
			end
		end
	end),
	"Java edits must reach JDTLS"
)
for _, notification in ipairs(starts[1].notifications) do
	if notification.method == "textDocument/didOpen" then
		assert(notification.params.textDocument.languageId == "java", "Only Java documents may be sent to JDTLS")
	end
end
workspace:stop(true)
assert(vim.wait(1000, function()
	return vim.lsp.get_client_by_id(workspace.id) == nil
end))
vim.lsp.rpc.start, require("kross").attach = rpc_start, kross_attach

local fake_jdtls = { name = "jdtls", id = 1001, config = { root_dir = project } }
local fake_copilot = { name = "copilot", id = 1002 }
vim.lsp.get_client_by_id = function(id)
	return id == 1001 and fake_jdtls or fake_copilot
end
vim.lsp.get_clients = function(opts)
	return opts and opts.name == "jdtls" and { fake_jdtls } or {}
end
vim.lsp.enable = function() end
spec("lsp").config()
local attached_config
package.loaded.jdtls = {
	start_or_attach = function(value)
		attached_config = value
	end,
}
package.loaded["jdtls.setup"] = {
	find_root = function()
		return project
	end,
}
package.loaded["mcdev.jdtls"] = {
	extend_config = function()
		return true
	end,
}
vim.api.nvim_set_current_buf(java)
spec("jdtls").config()
assert(attached_config)
local sent_params, sent_method, sent_handler
local conversion_client = {
	id = 1003,
	server_capabilities = {},
	request = function(_, method, params, handler)
		sent_params, sent_method, sent_handler = params, method, handler
		return true, 42
	end,
}
attached_config.on_init(conversion_client)
local lsp_diagnostic = {
	message = "Missing import",
	code = "16777218",
	data = { arguments = { "Type" } },
	range = { start = { line = 0, character = 7 }, ["end"] = { line = 0, character = 11 } },
}
local request_params = {
	context = {
		diagnostics = {
			{ lnum = 0, col = 13, user_data = { lsp = lsp_diagnostic } },
			lsp_diagnostic,
		},
	},
}
local requested, request_id = conversion_client:request("textDocument/codeAction", request_params)
assert(requested and request_id == 42)
assert(sent_method == "textDocument/codeAction")
assert(vim.deep_equal(sent_params.context.diagnostics, { lsp_diagnostic, lsp_diagnostic }))
assert(request_params.context.diagnostics[1].range == nil, "Converting MC diagnostics must not mutate the caller")

local completion_error, completion_result, completion_context
conversion_client:request("textDocument/completion", {}, function(err, result, ctx)
	completion_error, completion_result, completion_context = err, result, ctx
end)
local response = { isIncomplete = false, items = { { label = "clone" } } }
local context = { client_id = conversion_client.id }
sent_handler(nil, response, context)
local cache = require("blink.cmp.sources.lsp.cache")
cache.set({ id = 1, pos = { col = 8 } }, conversion_client, {
	is_incomplete_forward = completion_result.isIncomplete,
	items = completion_result.items,
})
assert(
	cache.get({ id = 1, pos = { col = 19 } }, conversion_client) == nil,
	"Typing BlockEntity after a complete whitespace response must refetch Java class candidates"
)
assert(completion_result.items == response.items and completion_context == context)
cache.entries[conversion_client.id] = nil
local completion_failure = { code = -32603, message = "Completion failed" }
sent_handler(completion_failure, nil, context)
assert(completion_error == completion_failure and completion_result == nil and completion_context == context)

vim.api.nvim_exec_autocmds("LspAttach", { buffer = java, data = { client_id = 1001 } })
attached_config.on_attach(fake_jdtls, java)
vim.wait(20, function()
	return false
end)
-- An unrelated client attaching later must not replace Java navigation.
vim.api.nvim_exec_autocmds("LspAttach", { buffer = java, data = { client_id = 1002 } })
local maps = {}
for _, map in ipairs(vim.api.nvim_buf_get_keymap(java, "n")) do
	maps[map.lhs] = map
end
assert(maps.gd and maps.gr and maps[" md"] and maps[" mr"] and maps[" mh"])
assert(maps.gd.desc ~= "Mcdev go to definition" and maps.gr.desc ~= "Mcdev find references")
local normal_calls, kotlin_source_calls = 0, 0
vim.lsp.buf.definition = function()
	normal_calls = normal_calls + 1
end
local kross_definition = require("kross").definition
require("kross").definition = function()
	kotlin_source_calls = kotlin_source_calls + 1
end
maps.gd.callback()
assert(kotlin_source_calls == 1 and normal_calls == 0, "Java gd must use kross after unrelated clients attach")
vim.bo[java].filetype = "python"
maps.gd.callback()
assert(normal_calls == 1 and kotlin_source_calls == 1, "Non-Java gd must use the current LSP function")
vim.bo[java].filetype = "java"
require("kross").definition = kross_definition
local kross = require("kross")
local references, kross_references = vim.lsp.buf.references, kross.references
local reference_calls, kotlin_reference_calls = 0, 0
vim.lsp.buf.references = function()
	reference_calls = reference_calls + 1
end
kross.references = function()
	kotlin_reference_calls = kotlin_reference_calls + 1
end
maps.gr.callback()
assert(kotlin_reference_calls == 1 and reference_calls == 0, "Java gr must use Kotlin semantic references")
vim.bo[java].filetype = "python"
maps.gr.callback()
assert(reference_calls == 1 and kotlin_reference_calls == 1, "Non-Java references retain their LSP")
vim.bo[java].filetype = "java"
kross.references = nil
maps.gr.callback()
assert(reference_calls == 2, "Older kross versions must retain standard references")
vim.lsp.buf.references, kross.references = references, kross_references

local feedkeys, kross_rename = vim.api.nvim_feedkeys, kross.rename
local commands, rename_fallback = {}, nil
vim.api.nvim_feedkeys = function(command, mode)
	assert(mode == "n")
	commands[#commands + 1] = command
end
kross.rename = function(new_name, opts)
	assert(new_name == nil)
	rename_fallback = opts.fallback
end
vim.api.nvim_set_current_buf(java)
vim.api.nvim_buf_set_lines(java, 0, -1, false, { "class Test { int field; }" })
vim.api.nvim_win_set_cursor(0, { 1, 17 })
maps[" rn"].callback()
assert(rename_fallback and #commands == 0, "Kotlin resolution must precede the Java rename UI")
rename_fallback()
assert(commands[1] == ":IncRename field", "Ordinary Java must retain editable IncRename input")
vim.api.nvim_set_current_buf(kotlin)
rename_fallback()
assert(#commands == 1, "A late rename callback must not type into another buffer")
vim.api.nvim_set_current_buf(java)
kross.rename = nil
maps[" rn"].callback()
assert(commands[2] == ":IncRename field", "Older kross versions retain IncRename")
vim.bo[java].filetype = "python"
maps[" rn"].callback()
assert(commands[3] == ":IncRename field", "Non-Java rename retains IncRename")
vim.bo[java].filetype = "java"
vim.api.nvim_feedkeys, kross.rename = feedkeys, kross_rename
local mc_calls = 0
vim.api.nvim_buf_set_lines(java, 0, -1, false, { "// 日本語 foo" })
local mc_location = {
	uri = vim.uri_from_bufnr(java),
	range = { start = { line = 0, character = 7 }, ["end"] = { line = 0, character = 10 } },
}
require("mcdev.navigation").definition = function(bufnr, _, cb)
	assert(bufnr == java)
	mc_calls = mc_calls + 1
	cb({ mc_location })
end
maps[" md"].callback()
assert(mc_calls == 1 and vim.api.nvim_win_get_cursor(0)[2] == 13, "MC definition must decode UTF-16 positions")
require("mcdev.navigation").references = function(bufnr, _, cb)
	assert(bufnr == java)
	cb({ mc_location })
end
maps[" mr"].callback()
assert(vim.fn.getqflist()[1].col == 14, "MC references must convert UTF-16 to quickfix byte columns")
vim.cmd.cclose()

mcdev_spec.config({ dir = lazy .. "/mcdev-nvim" }, mcdev_spec.opts({ dir = lazy .. "/mcdev-nvim" }))
local diagnostics = require("mcdev.diagnostics")
local fetch, fetch_count, invalid_selector = diagnostics.fetch, 0, true
diagnostics.fetch = function(bufnr, _, callback)
	assert(bufnr == java)
	fetch_count = fetch_count + 1
	callback(invalid_selector and {
		{
			message = "Unknown Mixin method",
			severity = "error",
			code = "MIXIN_UNRESOLVED_INJECT_METHOD",
			range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 1 } },
		},
	} or {})
end
vim.api.nvim_exec_autocmds("TextChangedI", { buffer = java })
assert(
	vim.wait(1500, function()
		return #vim.diagnostic.get(java, { namespace = diagnostics.namespace }) == 1
	end),
	"Unsaved Mixin edits must publish diagnostics"
)
invalid_selector = false
vim.api.nvim_buf_set_lines(java, 0, -1, false, { "// corrected without saving" })
vim.api.nvim_exec_autocmds("TextChangedP", { buffer = java })
assert(
	vim.wait(1500, function()
		return fetch_count >= 2 and #vim.diagnostic.get(java, { namespace = diagnostics.namespace }) == 0
	end),
	"Correcting a Mixin selector with the completion menu open must clear the error"
)
diagnostics.stop()
diagnostics.fetch = fetch
local resolve_calls = 0
fake_jdtls.offset_encoding = "utf-16"
fake_jdtls.request = function(_, method, action, callback, bufnr)
	assert(method == "codeAction/resolve" and bufnr == java and action.kind == "source.organizeImports")
	resolve_calls = resolve_calls + 1
	callback(nil, {
		edit = {
			changes = {
				[vim.uri_from_bufnr(java)] = {
					{
						range = { start = { line = 0, character = 0 }, ["end"] = { line = 0, character = 0 } },
						newText = "import example.Type;\n",
					},
				},
			},
		},
	})
end
require("mcdev.code_action").apply({ kind = "source.organizeImports", data = { pid = "0", rid = "0" } }, java)
assert(resolve_calls == 1 and vim.api.nvim_buf_get_lines(java, 0, 1, false)[1] == "import example.Type;")
require("mcdev.code_action").apply({ edit = { changes = {} } }, java)
assert(resolve_calls == 1, "Already resolved MC actions must apply without another resolve")

local kotlin_plugin = require("kotlin")
local kotlin_setup, kotlin_opts = kotlin_plugin.setup
kotlin_plugin.setup = function(opts)
	kotlin_opts = opts
end
spec("kotlin").config()
kotlin_plugin.setup = kotlin_setup
vim.env.MASON = vim.fn.stdpath("data") .. "/mason"
vim.api.nvim_set_current_buf(kotlin)
kotlin_plugin.setup_kotlin_lsp(kotlin_opts)
assert(vim.deep_equal(vim.lsp.config.kotlin_lsp.filetypes, { "kotlin" }), "Kotlin LSP must never attach to Java")

local sub_actions = 0
package.loaded["sub_action"] = {
	open = function(opts)
		assert(opts == nil)
		sub_actions = sub_actions + 1
	end,
}
local action_spec = spec("sub-action")
assert(#action_spec.keys == 1 and action_spec.keys[1][1] == "gra")
local code_action = action_spec.keys[1][2]
vim.api.nvim_set_current_buf(java)
code_action()
vim.api.nvim_set_current_buf(kotlin)
code_action()
assert(sub_actions == 2, "Java and Kotlin must use sub-action")

local execute = attached_config.handlers["workspace/executeClientCommand"]
local candidates = {
	{ fullyQualifiedName = "java.util.logging.Level", id = "logging" },
	{ fullyQualifiedName = "net.minecraft.world.level.Level", id = "minecraft" },
}
local params = {
	command = "java.action.organizeImports.chooseImports",
	arguments = {
		vim.uri_from_bufnr(java),
		{ { candidates = candidates }, { candidates = { candidates[1] } } },
	},
}
local select = vim.ui.select
local function choose_imports(cancel)
	vim.ui.select = function(items, _, callback)
		callback(not cancel and items[2] or nil)
	end
	local result
	local co = coroutine.create(function()
		result = execute(nil, params, { client_id = 1001 })
	end)
	assert(coroutine.resume(co))
	assert(vim.wait(1000, function()
		return coroutine.status(co) == "dead"
	end))
	return result
end
local choices = choose_imports(false)
assert(#choices == 2 and choices[1].id == "minecraft" and choices[2].id == "logging")
assert(choose_imports(true) == vim.NIL, "Cancel must abort imports without returning an error object as choices")
vim.ui.select = select
local result, response_error = execute(nil, { command = "codex.test.unknown" }, { client_id = 1001 })
assert(result == nil and response_error.code == vim.lsp.protocol.ErrorCodes.MethodNotFound)

local formatted = buffer("/src/main/java/example/Formatting.java", "java", {
	"class Formatting {",
	"  void test() {",
	'    System.out.println("ok");',
	"  }",
	"}",
})
vim.bo[formatted].shiftwidth, vim.bo[formatted].tabstop, vim.bo[formatted].softtabstop = 4, 4, 4
require("guess-indent").setup(spec("guess-indent").opts)
require("guess-indent").set_from_buffer(formatted, true, true)
assert(vim.bo[formatted].shiftwidth == 4, "GuessIndent must not restore Java's old two-space indent")
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin" .. (vim.fn.has("win32") == 1 and ";" or ":") .. vim.env.PATH
local conform = require("conform")
conform.setup(spec("conform").opts)
vim.api.nvim_exec_autocmds("BufWritePre", { group = "Conform", buffer = formatted })
assert(
	vim.api.nvim_buf_get_lines(formatted, 1, 2, false)[1] == "    void test() {",
	"Java formatter must use four spaces"
)
local format, format_calls = conform.format, {}
conform.format = function(opts, callback)
	format_calls[#format_calls + 1] = opts
	if callback then
		callback("format spy")
	end
end
vim.api.nvim_exec_autocmds("BufWritePre", { group = "Conform", buffer = formatted })
vim.api.nvim_exec_autocmds("BufWritePost", { group = "Conform", buffer = formatted })
assert(#format_calls == 1 and format_calls[1].async == false, "Java save must finish formatting before code actions")
vim.api.nvim_exec_autocmds("BufWritePre", { group = "Conform", buffer = kotlin })
vim.api.nvim_exec_autocmds("BufWritePost", { group = "Conform", buffer = kotlin })
assert(#format_calls == 2 and format_calls[2].async == true, "Kotlin retains asynchronous save formatting")
conform.format = format

vim.fn.jobstart = function()
	error("A buffer save must not start a Gradle build")
end
vim.api.nvim_exec_autocmds("BufWritePost", { buffer = kotlin })
vim.wait(350, function()
	return false
end)
assert(vim.v.errmsg == "", vim.v.errmsg)

assert(spec("treesitter").lazy == false)
require("nvim-treesitter").setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
assert(vim.treesitter.query.get("kotlin", "highlights"), "Kotlin parser/query must be compatible")
for _, file in ipairs(vim.fn.glob(config .. "/**/*.lua", false, true)) do
	assert(loadfile(file))
end
print(
	"PASS: Kotlin-first JDTLS/MC/kross startup and reuse, Kotlin-only attachment, Java full-document sync, unsaved Mixin diagnostic updates, Java completion refetch and error forwarding, Java Tree-sitter ownership and synchronous four-space save formatting, import selection/cancel/RPC errors, action routing, package templates, save/lint order, Gradle task + quickfix, navigation ownership, no save-time build, Kotlin query"
)
