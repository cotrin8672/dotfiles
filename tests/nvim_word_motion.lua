-- Run from the repository root: nvim --headless -u NONE -i NONE -l tests/nvim_word_motion.lua
vim.opt.rtp:prepend("dot_config/nvim")
local data = vim.fn.stdpath("data") .. "/lazy/"
for _, plugin in ipairs({ "extend_word_motion.nvim", "tinysegmenter.nvim", "nvim-spider" }) do
	vim.opt.rtp:append(data .. plugin)
end
require("plugins.extend-word-motion").config()

local function set_lines(lines)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

local function keys(input)
	vim.api.nvim_feedkeys(vim.keycode(input), "mx", false)
end

local function col(expected)
	local actual = vim.fn.col(".")
	assert(actual == expected, ("expected column %d, got %d"):format(expected, actual))
end

set_lines({ "foo_barBaz 今回はテストです" })
keys("2w")
col(8) -- Baz
keys("w")
col(12) -- 今
keys("w")
col(18) -- は

set_lines({ "foo_barBaz" })
keys("ve")
col(3)
keys("<Esc>")

set_lines({ "foo_bar", "baz_quux" })
keys("ceX<Esc>j0.")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "X_bar", "X_quux" }))

for _, key in ipairs({ "w", "b", "e", "ge" }) do
	assert(vim.fn.maparg(key, "s") == "", "Select mode must keep ordinary typing for " .. key)
end
print("word motion checks passed")
