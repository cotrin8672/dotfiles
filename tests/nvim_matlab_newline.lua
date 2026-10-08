-- nvim --headless -u NONE -i NONE -n -l tests/nvim_matlab_newline.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-autopairs")
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.autoindent = true
vim.opt.hidden = true
vim.opt.showmode = false
vim.opt.report = 9999
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
package.loaded["blink.cmp"] = {
	accept = function()
		return false
	end,
}
require("config.matlab.editing").setup()
local spec = require("plugins.nvim-autopairs")
spec.config(nil, spec.opts)

local count = 0
local results = {}
local function keys(input)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(input, true, false, true), "xt", false)
	vim.wait(10, function()
		return false
	end)
end

local function shape(buf)
	local root = vim.treesitter.get_parser(buf, "matlab"):parse(true)[1]:root()
	local function visit(node)
		assert(not node:missing() and node:type() ~= "ERROR", "Invalid MATLAB syntax: " .. root:sexpr())
		if vim.tbl_contains({ "line_continuation", "comment", ",", ";", "\n" }, node:type()) then
			return nil
		end
		local children = {}
		for child in node:iter_children() do
			local child_shape = visit(child)
			if child_shape then
				table.insert(children, child_shape)
			end
		end
		return { node:type(), node:child_count() > 0 and children or vim.treesitter.get_node_text(node, buf) }
	end
	return visit(root)
end

local function check(marked, expected, options)
	options = options or {}
	local lines = vim.deepcopy(marked)
	local row, col
	for index, text in ipairs(lines) do
		local start = text:find("<cursor>", 1, true)
		if start then
			assert(not row, "Exactly one cursor per case")
			row, col = index, start - 1
			lines[index] = text:sub(1, col) .. text:sub(start + 8)
		end
	end
	local buf = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo.filetype = "matlab"
	vim.bo.indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
	vim.bo.expandtab = options.expandtab ~= false
	vim.bo.shiftwidth = options.width or 4
	if options.formatoptions then
		vim.bo.formatoptions = options.formatoptions
	end
	local original_shape = options.semantic and shape(buf)
	vim.api.nvim_win_set_cursor(0, { row, math.min(col, math.max(#lines[row] - 1, 0)) })
	keys((col == #lines[row] and "A" or "i") .. (options.input or "<CR>") .. "<Esc>")
	local actual = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	table.insert(results, { before = lines, after = actual, semantic = options.semantic or false })
	if expected then
		assert(
			vim.deep_equal(actual, expected),
			vim.inspect(marked) .. "\nexpected " .. vim.inspect(expected) .. "\nactual " .. vim.inspect(actual)
		)
	end
	if original_shape then
		assert(
			vim.deep_equal(shape(buf), original_shape),
			"Enter changed operands, operators, rows, or executable statements: " .. vim.inspect(marked)
		)
	end
	if options.undo then
		keys("u")
		assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), lines), "One undo must restore the source")
		keys("<C-r>")
		assert(
			vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), actual),
			"Redo must restore the complete edit"
		)
	end
	vim.api.nvim_buf_delete(buf, { force = true })
	count = count + 1
end

-- Distinguish top-level statement/row separators from commas inside lists.
for _, item in ipairs({
	{ "f(a,<cursor> b);", { "f(a, ...", "    b);" } },
	{ "obj.f(a,<cursor> Name = value);", { "obj.f(a, ...", "    Name = value);" } },
	{ "f(a;<cursor> b);", nil, false }, -- incomplete input: do not invent a continuation
	{ "a = 1;<cursor> b = 2;", { "a = 1;", "b = 2;" } },
	{ "a = 1,<cursor> b = 2;", { "a = 1,", "b = 2;" } },
	{ "if ready;<cursor> f(); end", { "if ready;", "    f(); end" } },
	{ "if ready,<cursor> f(); end", { "if ready,", "    f(); end" } },
	{ "A = [1 2;<cursor> 3 4];", { "A = [1 2;", "    3 4];" } },
	{ "A = [1 2<cursor> 3 4];", { "A = [1 2 ...", "    3 4];" } },
	{ "C = {1 2;<cursor> 3 4};", { "C = {1 2;", "    3 4};" } },
	{ "C = {1 2<cursor> 3 4};", { "C = {1 2 ...", "    3 4};" } },
	{ "A = [f(1,<cursor> 2); g(3, 4)];", { "A = [f(1, ...", "    2); g(3, 4)];" } },
}) do
	check({ item[1] }, item[2], { semantic = item[3] ~= false, undo = true })
end

for _, item in ipairs({
	{ { "function f(first,<cursor> second)", "end" }, { "function f(first, ...", "    second)", "end" } },
	{ { "function [first,<cursor> second] = f(x)", "end" }, { "function [first, ...", "    second] = f(x)", "end" } },
	{ { "classdef (Sealed,<cursor> Hidden) C", "end" }, { "classdef (Sealed, ...", "    Hidden) C", "end" } },
	{
		{ "classdef C", "    properties (Access = private,<cursor> Constant)", "    end", "end" },
		{ "classdef C", "    properties (Access = private, ...", "        Constant)", "    end", "end" },
	},
	{ { "parfor (k = 1:3,<cursor> 2)", "end" }, { "parfor (k = 1:3, ...", "    2)", "end" } },
	{ { "value = A(1:end,<cursor> :);" }, { "value = A(1:end, ...", "    :);" } },
	{ { "value = C{first,<cursor> second};" }, { "value = C{first, ...", "    second};" } },
	{ { "f(<cursor>);" }, { "f( ...", "    ...", ");" } },
	{ { "function f(<cursor>)", "end" }, { "function f( ...", "    ...", ")", "end" } },
	{ { "f(a<cursor>);" }, { "f(a ...", "    ...", ");" } },
	{ { "A = [1 2<cursor>];" }, { "A = [1 2 ...", "    ...", "];" } },
	{ { "A = [1 2;<cursor>];" }, { "A = [1 2;", "    ...", "];" } },
}) do
	check(item[1], item[2], { semantic = true, undo = true })
end

-- Every whitespace boundary in these valid expressions preserves the parsed
-- operands/operators, literal bytes, argument ordering and array row structure.
for _, source in ipairs({
	"value = first + second .* third - fourth ./ fifth;",
	"value = first .^ second + third \\ fourth;",
	"value = 1:2:11;",
	"f(first, second, Name = value);",
	"f(A', B.', 'a,%...b', \"c,%...d\");",
	"A = [first second; third fourth];",
	"C = {first second; third fourth};",
}) do
	for position = 1, #source do
		if source:sub(position, position) == " " then
			check({ source:sub(1, position - 1) .. "<cursor>" .. source:sub(position) }, nil, { semantic = true })
		end
	end
end

for _, operator in ipairs({
	"+",
	"-",
	"*",
	"/",
	"\\",
	".*",
	"./",
	".\\",
	"^",
	".^",
	":",
	"==",
	"~=",
	"<=",
	">=",
	"&&",
	"||",
}) do
	check(
		{ "value = first " .. operator .. "<cursor> second;" },
		{ "value = first " .. operator .. " ...", "    second;" },
		{ semantic = true }
	)
end

-- Empty and repeated Enter inside a continuation must not create a syntax gap.
for _, input in ipairs({ "<CR>", "<CR><CR>", "<CR><CR><CR>" }) do
	check(
		{ "f( ...", "    first, ...<cursor>", "    second ...", ");" },
		nil,
		{ semantic = true, input = input, undo = true }
	)
	check(
		{ "function f( ...", "    first, ...<cursor>", "    second ...", ")", "end" },
		nil,
		{ semantic = true, input = input }
	)
end
check({ "f( ...", "    <cursor>second ...", ");" }, nil, { semantic = true })
check({ "if first && ...", "    <cursor>second", "end" }, nil, { semantic = true })
check({ "f( ...", "    final<cursor>", ");" }, { "f( ...", "    final ...", ");" }, { semantic = false, undo = true })
check({ "value = A( ...", "    end<cursor>", ");" }, { "value = A( ...", "    end ...", ");" })
check({ "f(a, % note<cursor>" }, { "f(a, ... % note", "    b);" }, { input = "<CR>b);", undo = true })
check(
	{ "value = first + % note<cursor>" },
	{ "value = first + ... % note", "    second;" },
	{ input = "<CR>second;", undo = true }
)
check(
	{ "if first && % note<cursor>" },
	{ "if first && ... % note", "    second", "    BODY", "end" },
	{ input = "<CR>second<CR>BODY" }
)

-- A comment suffix must remain a comment, including continuation-tail text.
for _, flags in ipairs({ "tcqj", "tcqjr" }) do
	check(
		{ "value = 1; % harmless <cursor>delete('file')" },
		{ "value = 1; % harmless ", "% delete('file')" },
		{ semantic = true, formatoptions = flags, undo = true }
	)
	check(
		{ "% 日本語<cursor>の説明" },
		{ "% 日本語", "% の説明" },
		{ semantic = true, formatoptions = flags }
	)
	check(
		{ "f( ...", "    first, ... % note <cursor>more", "    last ...", ");" },
		{ "f( ...", "    first, ... % note ", "    ... more", "    last ...", ");" },
		{ semantic = true, formatoptions = flags }
	)
end

-- Partial tokens/literals are editable drafts. Preserve their bytes and avoid
-- adding a block end; no claim is made that an Enter inside a quote is legal MATLAB.
check({ "text = 'a<cursor>,...%b';" }, { "text = 'a", ",...%b';" }, { undo = true })
check({ 'text = "a<cursor>,...%b";' }, { 'text = "a', ',...%b";' })
check({ "f(a, .<cursor>.. note", "    b);" }, { "f(a, .", "    .. note", "    b);" })
check({ "f(a, ..<cursor>. note", "    b);" }, { "f(a, ..", "    . note", "    b);" })
check({ "<cursor>if ready", "end" }, { "", "if ready", "end" }, { semantic = true })

-- Existing closing ends, even unformatted, and genuinely missing child ends.
check(
	{ "if outer", "    if inner<cursor>", "end", "end" },
	{ "if outer", "    if inner", "        BODY", "end", "end" },
	{ input = "<CR>BODY" }
)
check(
	{ "function f", "    if ready<cursor>", "end" },
	{ "function f", "    if ready", "        BODY", "    end", "end" },
	{ input = "<CR>BODY", undo = true }
)
check(
	{ "function f", "    if outer", "        if inner<cursor>", "    end", "end" },
	{ "function f", "    if outer", "        if inner", "            BODY", "        end", "    end", "end" },
	{ input = "<CR>BODY", undo = true }
)
check({ "    if ready<cursor>", "end" }, { "    if ready", "        BODY", "end" }, { input = "<CR>BODY" })
check({ "if ready<cursor>   ", "end" }, { "if ready", "    BODY", "end" }, { input = "<CR>BODY" })
check({ "if ready<cursor>" }, { "if ready", "  BODY", "end" }, { input = "<CR>BODY", width = 2 })
check({ "\tif ready<cursor>" }, { "\tif ready", "\t\tBODY", "\tend" }, { input = "<CR>BODY", expandtab = false })

local nested =
	{ "f( ...", "    g( ...", "        first, ...", "        second ...", "    ), ...", "    final ...", ");" }
local buf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, nested)
vim.bo.filetype = "matlab"
vim.bo.expandtab = true
vim.bo.shiftwidth = 4
vim.bo.indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
vim.cmd("silent normal! gg=G")
assert(
	vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), nested),
	"Nested opening/closing delimiters must keep their own indentation"
)
vim.api.nvim_buf_delete(buf, { force = true })

local function repeat_buffer(lines)
	local current = vim.api.nvim_create_buf(true, false)
	vim.api.nvim_set_current_buf(current)
	vim.api.nvim_buf_set_lines(current, 0, -1, false, lines)
	vim.bo.filetype = "matlab"
	vim.bo.expandtab = true
	vim.bo.shiftwidth = 4
	vim.bo.indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
	return current
end
for _, body in ipairs({ "BODY", "BODY<CR>NEXT", "if inner<CR>BODY" }) do
	local current = repeat_buffer({ "", "" })
	keys("iif ready<CR>" .. body .. "<Esc>")
	local before = vim.api.nvim_buf_get_lines(current, 0, -1, false)
	keys("G0.")
	local after = vim.api.nvim_buf_get_lines(current, 0, -1, false)
	local original_block = vim.list_slice(before, 1, #before - 1)
	assert(
		vim.deep_equal(vim.list_slice(after, #before), original_block),
		"Dot must repeat all nested/multiline inserted blocks including their ends"
	)
	keys("u")
	assert(
		vim.deep_equal(vim.api.nvim_buf_get_lines(current, 0, -1, false), before),
		"Dot and its generated ends must be one undo"
	)
	keys("<C-r>")
	assert(
		vim.deep_equal(vim.api.nvim_buf_get_lines(current, 0, -1, false), after),
		"Dot redo must restore the entire block"
	)
	vim.api.nvim_buf_delete(current, { force = true })
end

local repeated = repeat_buffer({ "if ready", "end", "", "if other" })
keys("A<CR>BODY<Esc>")
keys("G$.")
assert(
	vim.deep_equal(
		vim.api.nvim_buf_get_lines(repeated, 0, -1, false),
		{ "if ready", "    BODY", "end", "", "if other", "    BODY", "end" }
	),
	"Repeating an insert from an existing end must add a genuinely missing end"
)
vim.api.nvim_buf_delete(repeated, { force = true })

local balanced = repeat_buffer({ "if ready", "end", "", "if other", "end" })
keys("A<CR>BODY<Esc>")
vim.api.nvim_win_set_cursor(0, { 5, 0 })
keys(".")
assert(
	vim.deep_equal(
		vim.api.nvim_buf_get_lines(balanced, 0, -1, false),
		{ "if ready", "    BODY", "end", "", "if other", "    BODY", "end" }
	),
	"Repeating an insert must retain existing ends without duplication"
)
vim.api.nvim_buf_delete(balanced, { force = true })

print(
	"MATLAB newline: "
		.. count
		.. " cursor/sequence cases passed with syntax preservation, undo and nested indentation checks"
)
if vim.env.CODEX_MATLAB_NEWLINE_RESULTS then
	vim.fn.writefile({ vim.json.encode(results) }, vim.env.CODEX_MATLAB_NEWLINE_RESULTS)
end
