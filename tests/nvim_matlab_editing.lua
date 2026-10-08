-- From the repository root: nvim --headless -u NONE -i NONE -n -l tests/nvim_matlab_editing.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-autopairs")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter-endwise")
vim.g.mapleader = " "
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.autoindent = true
vim.opt.hidden = true
vim.opt.showmode = false
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
package.loaded["blink.cmp"] = {
	accept = function()
		return false
	end,
}
local editing = require("config.matlab.editing")
local syntax = require("config.matlab.syntax")
editing.setup()
local pair_spec = require("plugins.nvim-autopairs")
pair_spec.config(nil, pair_spec.opts)
-- The plugin can load for Lua or shell buffers; MATLAB must stay unsupported.
require("nvim-treesitter-endwise").init()
assert(not require("nvim-treesitter-endwise").is_supported("matlab"))

local count = 0
local function buffer(lines)
	local bufnr = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(bufnr)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].filetype = "matlab"
	vim.bo[bufnr].indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
	return bufnr
end
local function keys(text)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), "xt", false)
	vim.wait(10, function()
		return false
	end)
end
local function check(name, lines, row, text, expected)
	local bufnr = buffer(lines)
	vim.api.nvim_win_set_cursor(0, { row, #lines[row] - 1 })
	keys("A" .. text .. "<Esc>")
	local result = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	assert(
		vim.deep_equal(result, expected),
		name .. "\nexpected " .. vim.inspect(expected) .. "\nactual " .. vim.inspect(result)
	)
	vim.api.nvim_buf_delete(bufnr, { force = true })
	count = count + 1
end

for _, header in ipairs({
	"if",
	"if ready",
	"if ready % comment",
	"if x == 'a%b'",
	'if x == "a%b"',
	"for k = 1:3",
	"parfor k = 1:3",
	"parfor (k = 1:3, 2)",
	"while ready",
	"switch value",
	"try",
	"try % comment",
	"spmd",
	"spmd (2)",
	"function y = f(x)",
	"function [a, b] = f(x)",
	"function f(x)",
	"function f",
	"function obj.f(x)",
	"function y = f(x) % comment",
	"classdef Demo",
	"classdef Demo < handle",
	"if ready,",
	"if ready;",
	"if ready, value = 1;",
}) do
	check(header, { header }, 1, "<CR>BODY", { header, "    BODY", "end" })
end

check("existing end", { "if ready", "end" }, 1, "<CR>BODY", { "if ready", "    BODY", "end" })
check(
	"existing function end",
	{ "function y = f(x)", "end" },
	1,
	"<CR>BODY",
	{ "function y = f(x)", "    BODY", "end" }
)
check(
	"parent's end",
	{ "function y = f(x)", "    if ready", "end" },
	2,
	"<CR>BODY",
	{ "function y = f(x)", "    if ready", "        BODY", "    end", "end" }
)
check(
	"nested existing end",
	{ "function y = f(x)", "    if ready", "    end", "end" },
	2,
	"<CR>BODY",
	{ "function y = f(x)", "    if ready", "        BODY", "    end", "end" }
)
check("second newline", { "if ready" }, 1, "<CR>BODY<CR>NEXT", { "if ready", "    BODY", "    NEXT", "end" })
check(
	"continued condition",
	{ "if first && ...", "    second" },
	2,
	"<CR>BODY",
	{ "if first && ...", "    second", "    BODY", "end" }
)
check(
	"continued function",
	{ "function y = f( ...", "    a, ...", "    b ...", ")" },
	4,
	"<CR>BODY",
	{ "function y = f( ...", "    a, ...", "    b ...", ")", "    BODY", "end" }
)
check(
	"comma in incomplete call",
	{ "if ready", "    f(a,", "end" },
	2,
	"<CR>BODY",
	{ "if ready", "    f(a, ...", "        BODY", "end" }
)
check(
	"explicit continuation in incomplete call",
	{ "function f(x)", "    f(a, ...", "end" },
	2,
	"<CR>BODY",
	{ "function f(x)", "    f(a, ...", "        BODY", "end" }
)

for _, section in ipairs({
	"properties",
	"properties (Access = private)",
	"methods",
	"methods (Static)",
	"events",
	"enumeration",
}) do
	check(
		section,
		{ "classdef Demo", "    " .. section, "end" },
		2,
		"<CR>BODY",
		{ "classdef Demo", "    " .. section, "        BODY", "    end", "end" }
	)
end
for _, section in ipairs({ "arguments", "arguments (Input)", "arguments (Output)", "arguments (Repeating)" }) do
	check(
		section,
		{ "function f(x)", "    " .. section, "end" },
		2,
		"<CR>BODY",
		{ "function f(x)", "    " .. section, "        BODY", "    end", "end" }
	)
end

for _, line in ipairs({
	"if_flag = true;",
	"arguments_valid = true;",
	"end_index = 1;",
	"methods(obj)",
	"arguments = 1;",
	"% if ready",
	"if ready, value = 1; end",
	"a = data(end);",
	"s = 'if ready';",
	's = "if ready";',
	"s = 'a%b';",
	"s = '...';",
	"s = 'x,';",
	"a = data'; % if fake",
	"s = 'it''s fine';",
}) do
	check(line, { line }, 1, "<CR>BODY", { line, "BODY" })
end
check("block comment", { "%{", "if fake" }, 2, "<CR>BODY", { "%{", "if fake", "BODY" })

check("elseif", { "if ready", "elseif other", "end" }, 2, "<CR>BODY", { "if ready", "elseif other", "    BODY", "end" })
check("else", { "if ready", "else", "end" }, 2, "<CR>BODY", { "if ready", "else", "    BODY", "end" })
check("catch", { "try", "catch err", "end" }, 2, "<CR>BODY", { "try", "catch err", "    BODY", "end" })
check(
	"case",
	{ "switch value", "    case 1", "end" },
	2,
	"<CR>BODY",
	{ "switch value", "    case 1", "        BODY", "end" }
)
check(
	"otherwise",
	{ "switch value", "    otherwise", "end" },
	2,
	"<CR>BODY",
	{ "switch value", "    otherwise", "        BODY", "end" }
)
check(
	"existing continuation",
	{ "if first && ... tail comment" },
	1,
	"<CR>second",
	{ "if first && ... tail comment", "    second" }
)
check("operator continuation", { "if first &&" }, 1, "<CR>second", { "if first && ...", "    second" })
check("cell continuation", { "data = {" }, 1, "<CR>item", { "data = { ...", "    item" })
check(
	"flush-left nested function",
	{ "function outer", "function inner", "end", "end" },
	1,
	"<CR>BODY",
	{ "function outer", "    BODY", "function inner", "end", "end" }
)
check("comment tail", { "value = 1; % comment," }, 1, "<CR>BODY", { "value = 1; % comment,", "BODY" })
check("complete literal", { "value = 'a%b'" }, 1, "<CR>BODY", { "value = 'a%b'", "BODY" })

local middle = buffer({ "for k = 1:3" })
vim.api.nvim_win_set_cursor(0, { 1, 5 })
keys("a<CR><Esc>")
assert(
	vim.deep_equal(vim.api.nvim_buf_get_lines(middle, 0, -1, false), { "for k  ...", "    = 1:3" }),
	"mid-header newline must not insert an end or destroy suffix"
)
vim.api.nvim_buf_delete(middle, { force = true })

local indent_cases = {
	{ "function y = first(x)", "    y = x;", "function y = second(x)", "    y = x + 1;" },
	{ "function y = first(x)", "    y = x;", "function y = second( ...", "    x ...", ")", "    y = x + 1;" },
	{ "function outer", "    function inner", "    end", "end" },
	{ "function f(x)", "    arguments", "        x (1,1) double", "    end", "    value = x;", "end" },
	{ "function f(x)", "    if_flag = 1;", "    arguments_valid = true;", "    end_index = 1;", "end" },
	{ "function f(x)", "    if ready, value = 1; end", "    value = 2;", "end" },
	{ "function f(x)", "    %{", "    if fake", "    %}", "    value = 2;", "end" },
	{ "if first && ...", "    second", "    value = 1;", "end" },
	{ "function f( ...", "    first, ...", "    second ...", ")", "    value = 1;", "end" },
	{
		"switch value",
		"    case 1",
		"        if ready",
		"            value = 1;",
		"        end",
		"        value = 2;",
		"    otherwise",
		"        value = 3;",
		"end",
	},
	{
		"switch outer",
		"    case 1",
		"        switch inner",
		"            case 2",
		"                action();",
		"        end",
		"        more();",
		"end",
	},
	{
		"function f(x)",
		"    %{",
		"    %{",
		"    %}",
		"    if fake",
		"    %}",
		"    value = 1;",
		"end",
	},
	{
		"classdef Demo",
		"    properties",
		"        value double",
		"    end",
		"    methods",
		"        function f(obj)",
		"            value = obj.value;",
		"        end",
		"    end",
		"end",
	},
	{ "value = [ ...", "    1 2; ...", "    3 4 ...", "];", "next = 1;" },
	{ "function f(x)", "    methods(obj);", "    next = 1;", "end" },
}
for _, expected in ipairs(indent_cases) do
	local buf = buffer(expected)
	vim.cmd("silent normal! gg=G")
	local result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	assert(
		vim.deep_equal(result, expected),
		"indent\nexpected " .. vim.inspect(expected) .. "\nactual " .. vim.inspect(result)
	)
	vim.api.nvim_buf_delete(buf, { force = true })
end

local mapping_buf = buffer({ "f(first, second);" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
keys(" s")
local split = { "f( ...", "    first, ...", "    second ...", ");" }
assert(
	vim.deep_equal(vim.api.nvim_buf_get_lines(mapping_buf, 0, -1, false), split),
	"leader s mapping must use MATLAB split/join"
)
keys(".")
assert(
	vim.deep_equal(vim.api.nvim_buf_get_lines(mapping_buf, 0, -1, false), { "f(first, second);" }),
	"dot repeat must join"
)
keys(".")
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(mapping_buf, 0, -1, false), split), "dot repeat must split again")
vim.api.nvim_buf_delete(mapping_buf, { force = true })

local bufnr = buffer({ "function f(x)", "    arguments_valid = true;", "end" })
vim.cmd("silent normal! gg=G")
assert(
	vim.deep_equal(
		vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
		{ "function f(x)", "    arguments_valid = true;", "end" }
	)
)
assert(syntax.context(bufnr, 3).top == nil)
vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "    if ready, value = 1; end" })
vim.cmd("silent normal! gg=G")
assert(syntax.context(bufnr, 3).top == nil, "inline end must balance its own block")
vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "    end_index = 1;" })
assert(syntax.context(bufnr, 2).top.kind == "function", "end_index must not pop the function")
vim.api.nvim_buf_delete(bufnr, { force = true })

local nested = buffer({ "function outer", "function inner", "end", "end" })
assert(syntax.context(nested, 4).top == nil)
vim.api.nvim_buf_set_lines(nested, 3, 4, false, {})
assert(syntax.context(nested, 3).top == nil, "suffix edit must invalidate earlier parsed function nesting")
vim.api.nvim_buf_set_lines(nested, 0, -1, false, { "function outer", "function inner" })
assert(syntax.context(nested, 2).top.parent == nil)
vim.api.nvim_buf_set_lines(nested, 2, 2, false, { "end", "end" })
assert(syntax.context(nested, 2).top.parent.kind == "function", "appended ends must refresh earlier function ancestry")
vim.api.nvim_buf_delete(nested, { force = true })

print("MATLAB editing: " .. count .. " real-key cases plus lexical/indent/cache checks passed")
