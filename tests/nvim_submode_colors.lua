-- Run: nvim --headless -u NONE -i NONE -l tests/nvim_submode_colors.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "lualine.nvim", "nvim-submode", "mini.icons" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
vim.api.nvim_set_hl(0, "Normal", { bg = 0x16181A, fg = 0xFFFFFF })
vim.api.nvim_set_hl(0, "DiagnosticInfo", { fg = 0x5EA1FF })
dofile(config .. "/lua/plugins/submode.lua").config()
dofile(config .. "/lua/plugins/lualine.lua").config()
local sm, lualine = require("nvim-submode"), require("lualine")
local refresh, refreshes = lualine.refresh, 0
lualine.refresh = function(...)
	refreshes = refreshes + 1
	return refresh(...)
end
local function frame(label)
	local result = vim.api.nvim_eval_statusline(lualine.statusline(true), { maxwidth = 200, highlights = true })
	local start = assert(result.str:find(label, 1, true), result.str)
	local highlight
	for _, item in ipairs(result.highlights) do
		if item.start <= start - 1 then
			highlight = item
		end
	end
	return vim.api.nvim_get_hl(0, { name = highlight.groups[#highlight.groups], link = false }).bg
end
local function updated(before)
	assert(
		vim.wait(1000, function()
			return refreshes > before
		end, 5),
		"Submode must refresh lualine"
	)
end
local normal = frame("NORMAL")
local runtime = require("nvim-submode.runtime").create({
	id = "sub-action",
	display_name = "CODE ACTION",
	color = "#E3A875",
	mappings = { { lhs = "<Esc>", action = "exit" } },
})
local before = refreshes
runtime:start()
updated(before)
assert(frame("CODE ACTION") == 0xE3A875, "Code Action must use the configured amber")
assert(vim.api.nvim_get_hl(0, { name = "CursorLineNr", link = false }).fg == 0xE3A875)
before = refreshes
runtime:stop()
updated(before)
assert(frame("NORMAL") == normal, "Leaving must restore the Normal color")
local window = sm.build_submode({ name = "WINDOW", color = "#7DAEA3" }, {})
before = refreshes
sm.enable(window)
updated(before)
assert(frame("WINDOW") == 0x7DAEA3, "Legacy submodes must still share their colors")
before = refreshes
sm.disable()
updated(before)
assert(frame("NORMAL") == normal)
print("PASS: runtime and legacy submode colors, lualine updates, cursor accent and restored Normal colors")
