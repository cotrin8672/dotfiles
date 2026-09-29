-- Run from the repository root: nvim --headless -u NONE -l tests/nvim_mc_config.lua
-- Uses installed plugins, but never starts a language server or runs Gradle.
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
local lazy = vim.fn.stdpath("data") .. "/lazy"
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "nvim-lint", "kross.nvim", "nvim-treesitter", "overseer.nvim" }) do
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
require("kross").setup(spec("kross").opts)
local fake_jdtls = { name = "jdtls", id = 1001, config = { root_dir = project } }
local fake_kotlin = { name = "kotlin_lsp", id = 1002 }
vim.lsp.get_client_by_id = function(id)
	return id == 1001 and fake_jdtls or fake_kotlin
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
vim.api.nvim_exec_autocmds("LspAttach", { buffer = java, data = { client_id = 1001 } })
attached_config.on_attach(fake_jdtls, java)
vim.wait(20, function()
	return false
end)
-- Kotlin may attach after JDTLS to synchronize unsaved Java edits.
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
	"PASS: package templates, save/lint order, Gradle task + quickfix, navigation ownership, no save-time build, Kotlin query"
)
