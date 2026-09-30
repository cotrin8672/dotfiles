-- From the repository root: nvim --headless -u NONE -i NONE -n -l tests/nvim_tabby.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "tabby.nvim", "mini.icons" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
vim.opt.hidden = true
vim.opt.wrap = false -- Tabline width must not include buffer-window wrapping.
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
	local name = string.format("%02d-VeryLongFileNameForTabbyOverflow.lua", index)
	vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/" .. name)
	bufs[index], names[index] = buf, name
end
local function frame()
	local result =
		vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = vim.o.columns, highlights = true })
	local raw = _G.TabbyRenderCached()
	local count = renders
	assert(_G.TabbyRenderCached() == raw and renders == count, "render cache must remain effective")
	assert(result.width <= vim.o.columns, "viewport must fit")
	assert(
		vim.fn.strdisplaywidth(result.str) == vim.o.columns,
		"wide character clipping must preserve cell widths: columns="
			.. vim.o.columns
			.. " actual="
			.. vim.fn.strdisplaywidth(result.str)
			.. " text="
			.. result.str
	)
	assert(not result.str:find("‹", 1, true) and not result.str:find("›", 1, true), "overflow must just be clipped")
	return result.str, raw, result
end
local function selected(index)
	assert(vim.api.nvim_get_current_buf() == bufs[index], "wrong buffer selected")
	local text, _, result = frame()
	local start = text:find(names[index], 1, true)
	assert(start, "selected filename must be visible: " .. text)
	local highlight
	for _, item in ipairs(result.highlights) do
		if item.start <= start - 1 then
			highlight = item
		end
	end
	assert(vim.tbl_contains(highlight.groups, "TabbyActive"), "current filename must retain its highlight")
	return text
end

vim.o.columns = 110
vim.api.nvim_set_current_buf(bufs[1])
local first = selected(1)
assert(
	first:find("03-Very", 1, true) and not first:find(names[3], 1, true),
	"right neighbor must remain partially visible"
)
assert(
	_G.TabbyRenderCached():find("%" .. bufs[3] .. "@TabbyOpenBuffer@", 1, true),
	"clipped neighbors must remain clickable"
)
spec.next_buffer()
assert(selected(2) == first, "viewport must stay still when the next buffer already fits")
for index = 3, #bufs do
	spec.next_buffer()
	selected(index)
end
local last = selected(#bufs)
assert(last ~= first, "viewport must follow selection")
spec.next_buffer()
selected(1)
spec.previous_buffer()
selected(#bufs)
for index = #bufs - 1, 1, -1 do
	spec.previous_buffer()
	selected(index)
end

local function margins(index)
	local text = selected(index)
	local head, tail = "  1 ●", "  "
	assert(text:sub(1, #head) == head and text:sub(-#tail) == tail)
	local viewport = text:sub(#head + 1, -#tail - 1)
	local start, finish = viewport:find(names[index], 1, true)
	local icon = require("mini.icons").get("file", vim.api.nvim_buf_get_name(bufs[index]))
	return vim.fn.strdisplaywidth(viewport:sub(1, start - 1)) - vim.fn.strdisplaywidth("" .. icon .. " "),
		vim.fn.strdisplaywidth(viewport:sub(finish + 1)) - vim.fn.strdisplaywidth("")
end
vim.o.columns = 500
selected(1)
vim.g.tabby_scrolloff = 0
vim.o.columns = 110
vim.api.nvim_set_current_buf(bufs[3])
local _, right = margins(3)
assert(right == 0, "zero scrolloff must scroll only as far as needed")
vim.g.tabby_scrolloff = 8
local left
left, right = margins(3)
assert(left >= 8 and right == 8, "scrolloff must expose eight cells of the right neighbor")
vim.api.nvim_set_current_buf(bufs[2])
left, right = margins(2)
assert(left == 8 and right >= 8, "leftward scrolling must keep eight cells of the left neighbor")
vim.g.tabby_scrolloff = 1000
left, right = margins(2)
assert(math.abs(left - right) <= 1, "excessive scrolloff must center the current buffer")
vim.g.tabby_scrolloff = nil

vim.api.nvim_set_current_buf(bufs[6])
selected(6)
vim.o.columns = 80
selected(6)
vim.o.columns = 500
local wide = selected(6)
for _, name in ipairs(names) do
	assert(wide:find(name, 1, true), "resize must reveal all buffers when they fit")
end
local right_edge = names[#names] .. "  "
assert(wide:sub(-#right_edge) == right_edge, "buffers that fit must align with the right edge")

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
		text:find("日本語", 1, true),
		"oversized tabs must show their beginning without shortening the name: " .. text
	)
	assert(not text:find("END.lua", 1, true), "oversized tabs must be clipped at the right edge")
	if width >= 30 then
		assert(text:find("100%", 1, true), "clipped labels must preserve literal percent signs")
	end
	assert(vim.str_utfindex(text, "utf-8") > 0)
end
local unicode = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(unicode, vim.fn.tempname() .. "/á_日本語日本語.lua")
vim.api.nvim_set_current_buf(unicode)
for width = 30, 60 do
	vim.o.columns = width
	frame()
end
vim.api.nvim_set_current_buf(long)
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
	"PASS: fixed cell viewport, partially clipped neighbors and click targets, scrolloff in both directions, highlights, Unicode boundaries, Tab/Shift-Tab, wraparound, resize, deletion, cache, empty list"
)
