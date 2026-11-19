-- Run in an isolated Neovim with a UI (or --headless + :redraw!).
local a = vim.api
vim.o.laststatus, vim.o.showtabline = 0, 0
vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn = false, false, "no"
vim.bo.shiftwidth, vim.bo.tabstop = 4, 8
dofile("dot_config/nvim/lua/ui/indent_guides.lua").setup()
local function replace(row, text)
	a.nvim_buf_set_lines(0, row - 1, row, false, { text })
end
local function check(row, col, expected)
	vim.cmd.redraw({ bang = true })
	assert(vim.fn.screenstring(row, col) == expected, ("row %d col %d: expected %s"):format(row, col, expected))
end
a.nvim_buf_set_lines(0, 0, -1, false, { "if x", "    while y", "", "        body", "end" })
check(4, 5, "│")
check(3, 5, "│")
replace(4, "        body_edited")
check(4, 5, "│")
replace(4, "    body")
check(3, 5, " ")
replace(4, "\tbody")
check(4, 5, "│")
vim.bo.tabstop = 4
check(4, 5, "b")
a.nvim_buf_set_lines(0, 1, 2, false, {})
check(2, 1, " ")
