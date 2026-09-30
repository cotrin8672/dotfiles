-- Run from the repository root: nvim --headless -u NONE -l tests/nvim_picker_lifecycle.lua
-- Uses real picker windows and scheduled callbacks; starts no language server.
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
local lazy = vim.fn.stdpath("data") .. "/lazy"
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "snacks.nvim", "kross.nvim" }) do
	vim.opt.rtp:append(lazy .. "/" .. plugin)
end
vim.o.lines, vim.o.columns = 50, 160
local snacks_spec = dofile(config .. "/lua/plugins/snacks.lua")
snacks_spec.config(nil, { picker = snacks_spec.opts.picker })
Snacks.picker.setup()

local function drain()
	vim.wait(100, function()
		return false
	end, 5)
end

-- A preview may yield while resolving an action, then resume after confirmation closes it.
local previewed = false
vim.v.errmsg = ""
local picker = Snacks.picker.pick({
	title = "Code Actions",
	items = { { text = "Organize Imports" } },
	format = "text",
	preview = function(ctx)
		previewed = true
		vim.schedule(function()
			ctx.picker:close()
		end)
		assert(
			vim.wait(1000, function()
				return ctx.picker.preview == nil
			end, 5),
			"The picker must close while preview resolution is pending"
		)
	end,
})
assert(
	vim.wait(1000, function()
		return previewed and picker.preview == nil
	end, 5),
	"The real preview callback must run"
)
drain()
local preview_error = vim.v.errmsg

-- Native code actions and import type choices use the real Snacks vim.ui.select adapter.
for _, cancel in ipairs({ false, true, false }) do
	local callbacks, selected = 0, nil
	local select = vim.ui.select({ "Organize Imports", "Other action" }, {
		prompt = "Code actions",
	}, function(item)
		callbacks = callbacks + 1
		selected = item
	end)
	assert(vim.wait(1000, function()
		return select.shown and select.list:count() == 2
	end, 5))
	if cancel then
		select:close()
	else
		select.opts.actions.confirm(select, select.list:get(1))
	end
	assert(vim.wait(1000, function()
		return callbacks == 1 and select.preview == nil
	end, 5))
	drain()
	assert(callbacks == 1)
	if cancel then
		assert(selected == nil)
	else
		assert(selected == "Organize Imports")
	end
end
assert(vim.v.errmsg == "", "Real selection windows must confirm/cancel without errors")

local kross_spec = dofile(config .. "/lua/plugins/kross.lua")
kross_spec.config(nil, kross_spec.opts)
local kross = require("kross")
local attach, attached = kross.attach, 0
kross.attach = function(client)
	attached = attached + 1
	attach(client)
end
local get_client = vim.lsp.get_client_by_id
vim.lsp.get_client_by_id = function()
	return { name = "jdtls" }
end
vim.v.errmsg = ""
local buffer = vim.api.nvim_create_buf(false, true)
vim.api.nvim_exec_autocmds("LspAttach", { buffer = buffer, data = { client_id = 1 }, group = "kross" })
vim.api.nvim_buf_delete(buffer, { force = true })
drain()
local buffer_error = vim.v.errmsg
vim.lsp.get_client_by_id = get_client
kross.attach = attach

assert(preview_error == "", "Preview resumed after close: " .. preview_error)
assert(buffer_error == "", "Kross mapped a deleted buffer: " .. buffer_error)
assert(attached == 1, "Removing duplicate navigation maps must preserve Kross output attachment")
print("PASS: real Snacks preview close during resolution, select/confirm/cancel/reopen, Kross deleted-buffer lifecycle")
