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
assert(task_config.cmd[1]:find("project with spaces", 1, true), "Wrapper path must remain one argument")
local prefix = vim.fn.has("win32") == 1 and "C:/work/" or "/work/"
local qf = vim.fn.getqflist({
	efm = task_config.components[1].errorformat,
	lines = {
		"e: " .. vim.uri_from_fname(prefix .. "Drill.kt") .. ":90:34 Unresolved reference 'bad'.",
		prefix .. "Mixin.java:12: error: cannot find symbol",
	},
}).items
assert(#qf == 2 and qf[1].valid == 1 and qf[1].lnum == 90 and qf[1].col == 34)
assert(qf[2].valid == 1 and qf[2].lnum == 12)
assert(vim.fs.normalize(vim.api.nvim_buf_get_name(qf[1].bufnr)) == prefix .. "Drill.kt")
local unique = task_config.components[2]
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
						textDocumentSync = 1,
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
assert(vim.fn.filereadable(vim.api.nvim_buf_get_name(kotlin)) == 0, "Kotlin startup must not save the buffer")
assert(
	require("mcdev.protocol").active_jdtls_client(kotlin) == workspace,
	"MC requests must find the detached workspace"
)
local initialization = starts[1].initialize.initializationOptions
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
vim.fn.mkdir(project .. "/src/main/java/example", "p")
vim.fn.writefile(vim.api.nvim_buf_get_lines(java, 0, -1, false), vim.api.nvim_buf_get_name(java))
vim.api.nvim_set_current_buf(java)
vim.api.nvim_exec_autocmds("FileType", { buffer = java })
assert(#starts == 1 and workspace.attached_buffers[java], "Java must attach to the Kotlin-started workspace")
assert(not vim.lsp.semantic_tokens.get_at_pos(java, 0, 0), "Java must not start JDTLS semantic highlighting")
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
local sent_params
local conversion_client = {
	server_capabilities = {},
	request = function(_, method, params)
		assert(method == "textDocument/codeAction")
		sent_params = params
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
assert(vim.deep_equal(sent_params.context.diagnostics, { lsp_diagnostic, lsp_diagnostic }))
assert(request_params.context.diagnostics[1].range == nil, "Converting MC diagnostics must not mutate the caller")
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
local normal_calls = 0
vim.lsp.buf.definition = function()
	normal_calls = normal_calls + 1
end
maps.gd.callback()
assert(normal_calls == 1, "gd must resolve the current LSP/kross function after later attaches")
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

local native_actions, tiny_actions = 0, 0
vim.lsp.buf.code_action = function()
	native_actions = native_actions + 1
end
package.loaded["tiny-code-action"] = {
	code_action = function()
		tiny_actions = tiny_actions + 1
	end,
}
local code_action = spec("tiny-code-action").keys[1][2]
vim.api.nvim_set_current_buf(java)
code_action()
assert(native_actions == 1 and tiny_actions == 0, "Java must resolve actions only after selection")
vim.api.nvim_set_current_buf(kotlin)
code_action()
assert(native_actions == 1 and tiny_actions == 1, "Other filetypes retain code action previews")

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
	"PASS: Kotlin-first JDTLS/MC/kross startup and reuse, Kotlin-only attachment, Java Tree-sitter ownership and synchronous four-space save formatting, import selection/cancel/RPC errors, action routing, package templates, save/lint order, Gradle task + quickfix, navigation ownership, no save-time build, Kotlin query"
)
