-- Run: nvim --headless -u NONE -l tests/nvim_kotlin_actions.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.env.SUB_ACTION_ROOT or vim.fn.stdpath("data") .. "/lazy/sub-action.nvim")
local adapter = dofile(config .. "/lua/plugins/sub-action.lua").opts.preview
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/ImportProbe.kt")
local uri = vim.uri_from_bufnr(buf)
local file_url = "file://" .. vim.fs.normalize(vim.api.nvim_buf_get_name(buf))
local context = { client = { name = "kotlin_lsp" }, bufnr = buf }
local function preview(action)
	return adapter(action, context)
end
local function update(old, new)
	return {
		title = "Import",
		command = {
			command = "applyModCommand",
			arguments = {
				{ kind = "intellij.ModCommandData.UpdateFileText", fileUrl = file_url, oldText = old, newText = new },
			},
		},
	}
end

local old = 'val greeting = "${name} 日本語"'
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { old })
local action = update(old, "import example.name\n\n" .. old)
local copy = vim.deepcopy(action)
assert(adapter(action, { client = { name = "other" }, bufnr = buf }) == nil, "Only Kotlin LSP uses this adapter")
assert(preview({ command = "other.command" }) == nil, "Only applyModCommand uses this adapter")
assert(preview({ edit = { changes = {} }, command = action.command }) == nil, "WorkspaceEdits use native preview")
assert(not package.loaded["shared.intellij_mod_command"], "Unrelated actions must not load the adapter")
local diff = preview(action)
local mod = require("shared.intellij_mod_command")
assert(table.concat(diff, "\n"):find("+import example.name", 1, true))
assert(vim.deep_equal(preview(action.command), diff), "Bare LSP commands must also preview")
assert(preview({ edit = { changes = {} } }) == nil, "WorkspaceEdits use the native preview")
local composite = vim.deepcopy(action)
composite.command.arguments = {
	{
		kind = "intellij.ModCommandData.Composite",
		commands = {
			action.command.arguments[1],
			{ kind = "intellij.ModCommandData.Navigate" },
			update(action.command.arguments[1].newText, "final").command.arguments[1],
		},
	},
}
local files = assert(mod.text_updates(composite))
assert(#files == 1 and files[1].uri == uri and files[1].oldText == old and files[1].newText == "final")
local multi = vim.deepcopy(action)
local other = vim.deepcopy(action.command.arguments[1])
other.fileUrl = file_url:gsub("ImportProbe%.kt$", "Other.kt")
multi.command.arguments[#multi.command.arguments + 1] = other
assert(table.concat(preview(multi), "\n"):find("Other.kt", 1, true))
composite.command.arguments[1].commands[2] = { kind = "intellij.ModCommandData.ChooseAction" }
assert(preview(composite) == nil, "Interactive commands must not claim a complete preview")
assert(vim.deep_equal(action, copy), "Preview must not change the action")
assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == old, "Preview must not edit the source")
local executions, completed = 0, 0
require("sub_action.lsp").apply(
	{
		client = {
			commands = {},
			offset_encoding = "utf-16",
			exec_cmd = function(_, command, context, callback)
				assert(command == action.command and context.bufnr == buf)
				assert(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == old)
				executions = executions + 1
				callback()
			end,
		},
	},
	action,
	buf,
	function(err)
		assert(not err)
		completed = completed + 1
	end
)
assert(executions == 1 and completed == 1, "Confirmation must execute the original command once")
print("PASS: local Kotlin previews, bare commands, composite edits, multiple files, read-only preview and confirmation")
