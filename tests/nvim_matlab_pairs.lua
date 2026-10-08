-- nvim --headless -i NONE -u NONE -l tests/nvim_matlab_pairs.lua
-- Uses installed autopairs without starting MATLAB or a language server.
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-autopairs")
vim.opt.swapfile = false
vim.opt.showmode = false

local spec = dofile(config .. "/lua/plugins/nvim-autopairs.lua")
spec.config(nil, spec.opts)

local function type_text(filetype, input)
	vim.cmd("enew!")
	vim.bo.filetype = filetype
	-- Flush plain insert text before each expression mapping reads the cursor.
	local keys = "i" .. input:gsub(".", "<C-G>u%0") .. "<Esc>"
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "xt", false)
	return vim.api.nvim_get_current_line()
end

for _, input in ipairs({
	"if x < y",
	"if x <= y",
	"classdef C < handle",
	"A'",
	"A.'",
	"A(1)'",
	"[1 2]'",
	"{1}'",
	"value_'",
	"A''",
	'b = "text"\'',
	"s = 'hello'",
	"s = 'don''t'",
	"s = ''",
	's = "hello"',
	's = "double""quote"',
	"C = {'a', 'b'}",
	"A(1)'; s = 'label'",
	"[A(1)' 'label']",
	"%{",
	"% text ( [ { ' \"",
	"f(a); ... text ( [ { ' \"",
	"s = '(not a call)[or a matrix]{or a cell}'",
	's = "(not a call)[or a matrix]{or a cell}"',
}) do
	assert(type_text("matlab", input) == input, "Autopairs changed MATLAB input: " .. input)
end

assert(type_text("matlab", "s = '") == "s = ''", "Character vectors still need quote completion")
assert(type_text("matlab", "A(1)'; s = '") == "A(1)'; s = ''", "Transpose must not hide a later character vector")
assert(type_text("matlab", "A(1)'; s = \"") == 'A(1)\'; s = ""', "Transpose must not hide a later string opener")
assert(
	type_text("matlab", "s = \"text\"'; c = '") == "s = \"text\"'; c = ''",
	"String transpose must not hide a later character vector"
)
assert(type_text("lua", "s = '") == "s = ''", "Other filetypes must retain quote completion")
assert(type_text("cpp", "Vector<") == "Vector<>", "Other filetypes must retain angle completion")
assert(type_text("rust", "&'a") == "&'a", "Rust lifetimes must retain their quote rules")

vim.cmd("enew!")
vim.bo.filetype = "matlab"
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "%{", "", "%}" })
vim.api.nvim_win_set_cursor(0, { 2, 0 })
local input = "' \" ( [ {"
vim.api.nvim_feedkeys(
	vim.api.nvim_replace_termcodes("i" .. input:gsub(".", "<C-G>u%0") .. "<Esc>", true, false, true),
	"xt",
	false
)
assert(
	vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == input,
	"Block-comment text must not gain quotes or closing brackets"
)

print("MATLAB autopairs checks passed")
