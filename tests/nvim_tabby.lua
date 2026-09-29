-- From the repository root: nvim --headless -u NONE -i NONE -n -l tests/nvim_tabby.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "tabby.nvim", "mini.icons" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
vim.opt.hidden = true
require("mini.icons").setup()
local spec = require("plugins.tabby")
spec.config()
local render = require("tabby.tabline").render
local renders = 0
require("tabby.tabline").render = function()
	renders = renders + 1
	return render()
end

local bufs, names = {}, {}
for index = 1, 8 do
	local buf = index == 1 and vim.api.nvim_get_current_buf() or vim.api.nvim_create_buf(true, false)
	local name = string.format("VeryLongFileNameForTabbyOverflow%02d.lua", index)
	vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/" .. name)
	bufs[index], names[index] = buf, name
end
local function frame()
	local result = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = vim.o.columns })
	local raw = _G.TabbyRenderCached()
	local count = renders
	assert(_G.TabbyRenderCached() == raw and renders == count, "render cache must remain effective")
	assert(result.width <= vim.o.columns, "tabline must fit")
	return result.str, raw
end
local function selected(index)
	assert(vim.api.nvim_get_current_buf() == bufs[index], "wrong buffer selected")
	local text = frame()
	assert(text:find(names[index], 1, true), "selected filename must be visible: " .. text)
	return text
end

vim.o.columns = 110
vim.api.nvim_set_current_buf(bufs[1])
local first = selected(1)
assert(first:find("›", 1, true) and not first:find("‹", 1, true))
spec.next_buffer()
assert(selected(2) == first, "viewport must stay still when the next buffer already fits")
for index = 3, #bufs do
	spec.next_buffer()
	selected(index)
end
local last = selected(#bufs)
assert(last ~= first and last:find("‹", 1, true) and not last:find("›", 1, true))
spec.next_buffer()
selected(1)
spec.previous_buffer()
selected(#bufs)
for index = #bufs - 1, 1, -1 do
	spec.previous_buffer()
	selected(index)
end
vim.api.nvim_set_current_buf(bufs[6])
selected(6)
vim.o.columns = 80
selected(6)
vim.o.columns = 500
local wide = selected(6)
for _, name in ipairs(names) do
	assert(wide:find(name, 1, true), "resize must reveal all buffers when they fit")
end
assert(not wide:find("‹", 1, true) and not wide:find("›", 1, true))

vim.o.columns = 80
selected(6)
vim.api.nvim_buf_delete(bufs[5], { force = true })
selected(6)
vim.api.nvim_buf_set_lines(bufs[6], 0, -1, false, { "modified" })
vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = bufs[6] })
selected(6)

local long = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(long, vim.fn.tempname() .. "/日本語_100%_" .. string.rep("長い名前", 12) .. "_END.lua")
vim.api.nvim_set_current_buf(long)
for _, width in ipairs({ 80, 30, 12 }) do
	vim.o.columns = width
	local text, raw = frame()
	assert(raw:find("%" .. long .. "@TabbyOpenBuffer@", 1, true), "long buffer must retain its click target")
	assert(
		text:find(width >= 30 and "END.lua" or ".lua", 1, true),
		"oversized filename must remain identifiable: " .. text
	)
	assert(vim.str_utfindex(text, "utf-8") > 0)
end
vim.o.columns = 500
assert(frame():find("100%", 1, true), "percent signs in names must stay literal")

local scratch = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(scratch)
frame()
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
	if buf ~= scratch then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end
frame()
assert(vim.v.errmsg == "", vim.v.errmsg)
print(
	"PASS: Tab/Shift-Tab, stable viewport, wraparound, direct jumps, resize, deletion, modified labels, Unicode, long names, cache, empty list"
)
