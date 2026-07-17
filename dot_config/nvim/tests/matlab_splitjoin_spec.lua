local splitjoin = require("config.matlab.splitjoin")

local function create_buffer(text, row, col)
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, bufnr)
	vim.bo[bufnr].filetype = "matlab"
	vim.bo[bufnr].shiftwidth = 4
	local undolevels = vim.bo[bufnr].undolevels
	vim.bo[bufnr].undolevels = -1
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(text, "\n", { plain = true }))
	vim.bo[bufnr].undolevels = undolevels
	vim.api.nvim_win_set_cursor(0, { row, col })
	return bufnr
end

local function buffer_lines(bufnr)
	return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

local function contains_error(node)
	if node:type() == "ERROR" then
		return true
	end
	for child in node:iter_children() do
		if contains_error(child) then
			return true
		end
	end
	return false
end

local function assert_valid_matlab(bufnr)
	local tree = vim.treesitter.get_parser(bufnr, "matlab"):parse(true)[1]
	assert.is_false(contains_error(tree:root()))
end

local function assert_round_trip(case)
	local bufnr = create_buffer(case.text, case.row, case.col)
	local state0 = buffer_lines(bufnr)

	assert.is_true(splitjoin.toggle(bufnr), case.name .. " first split")
	local state1 = buffer_lines(bufnr)
	assert.is_true(#state1 > #state0, case.name .. " uses multiple lines")
	assert.is_truthy(table.concat(state1, "\n"):find("...", 1, true), case.name .. " adds continuations")
	assert_valid_matlab(bufnr)

	assert.is_true(splitjoin.toggle(bufnr), case.name .. " first join")
	local state2 = buffer_lines(bufnr)
	assert.same(state0, state2, case.name .. " restores the original bytes")
	assert_valid_matlab(bufnr)

	assert.is_true(splitjoin.toggle(bufnr), case.name .. " second split")
	local state3 = buffer_lines(bufnr)
	assert.same(state1, state3, case.name .. " restores the generated split bytes")
	assert_valid_matlab(bufnr)

	assert.is_true(splitjoin.toggle(bufnr), case.name .. " second join")
	assert.same(state0, buffer_lines(bufnr), case.name .. " remains stable after four toggles")
	assert_valid_matlab(bufnr)

	vim.api.nvim_buf_delete(bufnr, { force = true })
end

describe("MATLAB split/join", function()
	require("config.matlab.editing").setup()

	local cases = {
		{ name = "call arguments", text = "x = foo(a, b, c);", row = 1, col = 10 },
		{
			name = "call arguments with embedded separators",
			text = [[x = foo("a,b", 'c;d', [1, 2]);]],
			row = 1,
			col = 10,
		},
		{ name = "method call arguments", text = "y = obj.method(a, b, c);", row = 1, col = 18 },
		{
			name = "name-value call arguments",
			text = [[plot(x, y, "LineWidth", 2, "Color", [1, 0, 0]);]],
			row = 1,
			col = 20,
		},
		{
			name = "arguments beyond the old join length",
			text = "x = foo(first_really_long_argument_name, second_really_long_argument_name, third_really_long_argument_name, fourth_really_long_argument_name);",
			row = 1,
			col = 12,
		},
		{ name = "nested nearest arguments", text = "x = foo(a, bar(b, c), d);", row = 1, col = 17 },
		{ name = "nested outer arguments", text = "x = foo(a, bar(b, c), d);", row = 1, col = 8 },
		{ name = "function arguments", text = "function y = f(a, b, c)\nend", row = 1, col = 18 },
		{ name = "function arguments without outputs", text = "function f(a, b, c)\nend", row = 1, col = 13 },
		{ name = "function outputs", text = "function [a, b, c] = f(x)\nend", row = 1, col = 12 },
		{ name = "assignment outputs", text = "[a, b, c] = f(x);", row = 1, col = 4 },
		{ name = "lambda arguments", text = "f = @(x, y, z) x + y + z;", row = 1, col = 8 },
		{ name = "matrix with mixed separators", text = "M = [a b; c, d];", row = 1, col = 6 },
		{ name = "matrix column", text = "v = [a; b; c];", row = 1, col = 6 },
		{
			name = "matrix with nested calls",
			text = "M = [foo(a, b), 2; 3, bar(c, d)];",
			row = 1,
			col = 20,
		},
		{ name = "cell with rows", text = "C = {a, b; c, d};", row = 1, col = 6 },
		{
			name = "cell with embedded separators",
			text = [[C = {"a,b", 'c;d'; [1, 2], {3, 4}};]],
			row = 1,
			col = 6,
		},
		{ name = "binary expression by precedence", text = "y = a + b * c - d / e;", row = 1, col = 8 },
		{ name = "binary expression in a single argument", text = "y = foo(a + b - c);", row = 1, col = 12 },
		{ name = "logical expression", text = "flag = a > b && c ~= d || e;", row = 1, col = 10 },
		{ name = "range expression", text = "x = start:step:stop;", row = 1, col = 8 },
		{ name = "element-wise expression", text = "y = a .* b + c ./ d - e .^ f;", row = 1, col = 10 },
		{ name = "superclasses", text = "classdef X < A & B & C\nend", row = 1, col = 14 },
		{ name = "qualified superclasses", text = "classdef X < pkg.A & pkg.B & pkg.C\nend", row = 1, col = 18 },
		{
			name = "class attributes",
			text = "classdef (Abstract, Sealed = false) X\nend",
			row = 1,
			col = 12,
		},
		{
			name = "property attributes",
			text = "classdef X\nproperties (SetAccess = private, Hidden)\nend\nend",
			row = 2,
			col = 14,
		},
		{
			name = "method attributes",
			text = "classdef X\nmethods (Static, Access = private)\nend\nend",
			row = 2,
			col = 12,
		},
		{
			name = "property dimensions",
			text = "classdef X\nproperties\n  x (1, :) double\nend\nend",
			row = 3,
			col = 6,
		},
		{
			name = "property validations",
			text = "classdef X\nproperties\n  x (1, :) double {mustBePositive, mustBeFinite}\nend\nend",
			row = 3,
			col = 28,
		},
		{
			name = "nested property validations",
			text = "classdef X\nproperties\n  x (1, :) double {mustBeMember(x, [1, 2]), mustBeFinite}\nend\nend",
			row = 3,
			col = 28,
		},
		{
			name = "noncanonical whitespace and trailing comment",
			text = "  x=foo( a ,b,  c ); % keep me",
			row = 1,
			col = 12,
		},
	}

	for _, case in ipairs(cases) do
		it("round-trips " .. case.name, function()
			assert_round_trip(case)
		end)
	end

	it("round-trips when the initial state is already split", function()
		local text = "x = foo(a, ...\n      b, ...\n      c);"
		local bufnr = create_buffer(text, 1, 10)
		local split0 = buffer_lines(bufnr)

		assert.is_true(splitjoin.toggle(bufnr))
		local joined1 = buffer_lines(bufnr)
		assert.same({ "x = foo(a, b, c);" }, joined1)
		assert.is_true(splitjoin.toggle(bufnr))
		assert.same(split0, buffer_lines(bufnr))
		assert.is_true(splitjoin.toggle(bufnr))
		assert.same(joined1, buffer_lines(bufnr))
		assert.is_true(splitjoin.toggle(bufnr))
		assert.same(split0, buffer_lines(bufnr))

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("round-trips the full call from leader s on its opening continuation", function()
		local text = table.concat({
			"                Ct_free = prop_RC( ...",
			"                    stepTime_normal, At, Ct, 0, Kappa_rate, ...",
			"                    detuning_sub, F, u, nu);",
		}, "\n")
		local bufnr = create_buffer(text, 1, 37)
		local split = buffer_lines(bufnr)

		vim.api.nvim_feedkeys(" s", "x", false)
		assert.same({
			"                Ct_free = prop_RC(stepTime_normal, At, Ct, 0, Kappa_rate, detuning_sub, F, u, nu);",
		}, buffer_lines(bufnr))
		vim.api.nvim_feedkeys(" s", "x", false)
		assert.same(split, buffer_lines(bufnr))

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("joins the reported prop_NR call from every opening continuation dot", function()
		local lines = {
			"        At_free = prop_NR( ...",
			"            stepTime_normal, At, Bt, Ct, 0, no_nr_cpl, Kappa_normal, Omega_normal, detuning_NR, Gamma_normal, u, nu, Raman_coef);",
		}
		local text = table.concat(lines, "\n")
		local continuation_col = assert(lines[1]:find("...", 1, true)) - 1

		for offset = 0, 2 do
			local bufnr = create_buffer(text, 1, continuation_col + offset)
			vim.api.nvim_feedkeys(" s", "x", false)
			assert.same({
				"        At_free = prop_NR(stepTime_normal, At, Bt, Ct, 0, no_nr_cpl, Kappa_normal, Omega_normal, detuning_NR, Gamma_normal, u, nu, Raman_coef);",
			}, buffer_lines(bufnr), "continuation dot " .. (offset + 1))
			vim.api.nvim_feedkeys(" s", "x", false)
			assert.same(lines, buffer_lines(bufnr), "continuation dot " .. (offset + 1) .. " round trip")
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("selects a continued call from every structural cursor position", function()
		local lines = {
			"x = prop_RC( ...",
			"    first, second, ...",
			"    third);",
		}
		local text = table.concat(lines, "\n")
		local opening_continuation = assert(lines[1]:find("...", 1, true)) - 1
		local middle_continuation = assert(lines[2]:find("...", 1, true)) - 1
		local positions = {
			{ "function name", 1, assert(lines[1]:find("prop_RC", 1, true)) - 1 },
			{ "opening parenthesis", 1, assert(lines[1]:find("(", 1, true)) - 1 },
			{ "first opening continuation dot", 1, opening_continuation },
			{ "middle opening continuation dot", 1, opening_continuation + 1 },
			{ "last opening continuation dot", 1, opening_continuation + 2 },
			{ "first argument", 2, assert(lines[2]:find("first", 1, true)) - 1 },
			{ "first middle continuation dot", 2, middle_continuation },
			{ "last middle continuation dot", 2, middle_continuation + 2 },
			{ "last argument", 3, assert(lines[3]:find("third", 1, true)) - 1 },
			{ "closing parenthesis", 3, assert(lines[3]:find(")", 1, true)) - 1 },
		}

		for _, position in ipairs(positions) do
			local bufnr = create_buffer(text, position[2], position[3])
			assert.is_true(splitjoin.toggle(bufnr), position[1])
			assert.same({ "x = prop_RC(first, second, third);" }, buffer_lines(bufnr), position[1])
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("selects the innermost call from its function name", function()
		local text = "x = outer(a, inner(b, c), d);"
		local bufnr = create_buffer(text, 1, assert(text:find("inner", 1, true)) - 1)

		assert.is_true(splitjoin.toggle(bufnr))
		assert.same({
			"x = outer(a, inner(b, ...",
			"    c), d);",
		}, buffer_lines(bufnr))

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("selects continued function arguments from signature boundaries", function()
		local lines = {
			"function y = solve( ...",
			"    alpha, beta, gamma)",
			"end",
		}
		local text = table.concat(lines, "\n")
		local positions = {
			{ "function name", 1, assert(lines[1]:find("solve", 1, true)) - 1 },
			{ "opening parenthesis", 1, assert(lines[1]:find("(", 1, true)) - 1 },
			{ "opening continuation", 1, assert(lines[1]:find("...", 1, true)) - 1 },
			{ "closing parenthesis", 2, assert(lines[2]:find(")", 1, true)) - 1 },
		}

		for _, position in ipairs(positions) do
			local bufnr = create_buffer(text, position[2], position[3])
			assert.is_true(splitjoin.toggle(bufnr), position[1])
			assert.same({ "function y = solve(alpha, beta, gamma)", "end" }, buffer_lines(bufnr), position[1])
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("selects anonymous-function arguments from the at sign", function()
		local text = "f = @(x, y, z) x + y + z;"
		local bufnr = create_buffer(text, 1, assert(text:find("@", 1, true)) - 1)

		assert.is_true(splitjoin.toggle(bufnr))
		assert.same({
			"f = @(x, ...",
			"    y, ...",
			"    z) x + y + z;",
		}, buffer_lines(bufnr))

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("selects bracketed containers from opening and closing delimiters", function()
		local cases = {
			{ text = "M = [a, b, c];", open = "[", close = "]" },
			{ text = "C = {a, b, c};", open = "{", close = "}" },
			{ text = "[a, b, c] = f();", open = "[", close = "]" },
		}

		for _, case in ipairs(cases) do
			for _, delimiter in ipairs({ case.open, case.close }) do
				local bufnr = create_buffer(case.text, 1, assert(case.text:find(delimiter, 1, true)) - 1)
				assert.is_true(splitjoin.toggle(bufnr), case.text .. " at " .. delimiter)
				assert.is_true(#buffer_lines(bufnr) > 1, case.text .. " at " .. delimiter)
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end
	end)

	it("joins every delimiter-led list from its opening continuation", function()
		local cases = {
			{
				name = "multiple outputs",
				text = "[ ...\n    a, b, c] = f();",
				continuation_row = 1,
				expected = { "[a, b, c] = f();" },
			},
			{
				name = "class attributes",
				text = "classdef ( ...\n    Abstract, Sealed) X\nend",
				continuation_row = 1,
				expected = { "classdef (Abstract, Sealed) X", "end" },
			},
			{
				name = "property dimensions",
				text = "classdef X\nproperties\n    value ( ...\n        1, :) double\nend\nend",
				continuation_row = 3,
				expected = { "classdef X", "properties", "    value (1, :) double", "end", "end" },
			},
			{
				name = "property validations",
				text = "classdef X\nproperties\n    value double { ...\n        mustBePositive, mustBeFinite}\nend\nend",
				continuation_row = 3,
				expected = {
					"classdef X",
					"properties",
					"    value double {mustBePositive, mustBeFinite}",
					"end",
					"end",
				},
			},
		}

		for _, case in ipairs(cases) do
			local line = vim.split(case.text, "\n", { plain = true })[case.continuation_row]
			local bufnr = create_buffer(case.text, case.continuation_row, assert(line:find("...", 1, true)) - 1)
			assert.is_true(splitjoin.toggle(bufnr), case.name)
			assert.same(case.expected, buffer_lines(bufnr), case.name)
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("rejects a comment on the opening continuation without partial joining", function()
		local text = "x = foo( ... % explanation\n    a, b, c);"
		local bufnr = create_buffer(text, 1, assert(text:find("...", 1, true)) - 1)
		local before = buffer_lines(bufnr)

		assert.is_false(splitjoin.toggle(bufnr))
		assert.same(before, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("discards a saved pair after an edit inside the target", function()
		local bufnr = create_buffer("x = foo(a, b, c);", 1, 10)
		assert.is_true(splitjoin.toggle(bufnr))
		vim.api.nvim_buf_set_text(bufnr, 1, 4, 1, 5, { "changed" })
		vim.api.nvim_win_set_cursor(0, { 2, 5 })

		assert.is_true(splitjoin.toggle(bufnr))
		assert.same({ "x = foo(a, changed, c);" }, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("keeps a saved pair across edits before the target", function()
		local bufnr = create_buffer("x = foo(a, b, c);", 1, 10)
		assert.is_true(splitjoin.toggle(bufnr))
		vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "% unrelated" })
		vim.api.nvim_win_set_cursor(0, { 2, 8 })

		assert.is_true(splitjoin.toggle(bufnr))
		assert.same({ "% unrelated", "x = foo(a, b, c);" }, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not join a continuation comment", function()
		local text = "x = foo(a, ... % explanation\n    b);"
		local bufnr = create_buffer(text, 1, 10)
		local before = buffer_lines(bufnr)

		assert.is_false(splitjoin.toggle(bufnr))
		assert.same(before, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not modify a syntax-error target", function()
		local bufnr = create_buffer("x = foo(a,, b);", 1, 10)
		local before = buffer_lines(bufnr)

		assert.is_false(splitjoin.toggle(bufnr))
		assert.same(before, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("round-trips through the actual leader mapping and dot repeat", function()
		local bufnr = create_buffer("x = foo(a, b, c);", 1, 10)
		local original = buffer_lines(bufnr)

		vim.api.nvim_feedkeys(" s", "x", false)
		local split = buffer_lines(bufnr)
		assert.is_true(#split > #original)

		vim.api.nvim_feedkeys(".", "x", false)
		assert.same(original, buffer_lines(bufnr))
		vim.api.nvim_feedkeys(".", "x", false)
		assert.same(split, buffer_lines(bufnr))
		vim.api.nvim_feedkeys(" s", "x", false)
		assert.same(original, buffer_lines(bufnr))

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("selects the nearest nested target", function()
		local bufnr = create_buffer("x = foo(a, bar(b, c), d);", 1, 17)

		assert.is_true(splitjoin.toggle(bufnr))
		local text = table.concat(buffer_lines(bufnr), "\n")
		assert.matches("foo%(a, bar%(b, %.%.%.", text)
		assert.matches("c%), d%)", text)

		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("keeps independent saved states for multiple targets", function()
		local bufnr = create_buffer("x = foo(a, b, c);\ny = bar(d, e, f);", 1, 10)
		local original = buffer_lines(bufnr)

		assert.is_true(splitjoin.toggle(bufnr))
		vim.api.nvim_win_set_cursor(0, { 4, 10 })
		assert.is_true(splitjoin.toggle(bufnr))
		vim.api.nvim_win_set_cursor(0, { 1, 8 })
		assert.is_true(splitjoin.toggle(bufnr))
		vim.api.nvim_win_set_cursor(0, { 2, 8 })
		assert.is_true(splitjoin.toggle(bufnr))

		assert.same(original, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("dot-repeats on a different target under the cursor", function()
		local bufnr = create_buffer("x = foo(a, b, c);\ny = bar(d, e, f);", 1, 10)

		vim.api.nvim_feedkeys(" s", "x", false)
		vim.api.nvim_win_set_cursor(0, { 4, 10 })
		vim.api.nvim_feedkeys(".", "x", false)

		local text = table.concat(buffer_lines(bufnr), "\n")
		assert.matches("foo%(a, %.%.%.", text)
		assert.matches("bar%(d, %.%.%.", text)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("preserves edits after a saved target", function()
		local bufnr = create_buffer("x = foo(a, b, c); % old", 1, 10)
		assert.is_true(splitjoin.toggle(bufnr))
		local last = vim.api.nvim_buf_line_count(bufnr) - 1
		local line = vim.api.nvim_buf_get_lines(bufnr, last, last + 1, false)[1]
		local comment = assert(line:find("old", 1, true)) - 1
		vim.api.nvim_buf_set_text(bufnr, last, comment, last, comment + 3, { "new" })
		vim.api.nvim_win_set_cursor(0, { last + 1, 4 })

		assert.is_true(splitjoin.toggle(bufnr))
		assert.same({ "x = foo(a, b, c); % new" }, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("reformats an argument inserted at the saved target boundary", function()
		local bufnr = create_buffer("x = foo(a, b, c);", 1, 10)
		assert.is_true(splitjoin.toggle(bufnr))
		local last = vim.api.nvim_buf_line_count(bufnr) - 1
		local line = vim.api.nvim_buf_get_lines(bufnr, last, last + 1, false)[1]
		local close = assert(line:find(")", 1, true)) - 1
		vim.api.nvim_buf_set_text(bufnr, last, close, last, close, { ", d" })
		vim.api.nvim_win_set_cursor(0, { last + 1, close + 2 })
		local edited_split = buffer_lines(bufnr)

		assert.is_true(splitjoin.toggle(bufnr))
		assert.same({ "x = foo(a, b, c, d);" }, buffer_lines(bufnr))
		assert.is_true(splitjoin.toggle(bufnr))
		assert.same(edited_split, buffer_lines(bufnr))
		assert.is_true(splitjoin.toggle(bufnr))
		assert.same({ "x = foo(a, b, c, d);" }, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("survives undo and creates a fresh reversible pair", function()
		local bufnr = create_buffer("x = foo(a, b, c);", 1, 10)
		local original = buffer_lines(bufnr)
		assert.is_true(splitjoin.toggle(bufnr))

		vim.cmd.undo()
		assert.same(original, buffer_lines(bufnr))
		vim.api.nvim_win_set_cursor(0, { 1, 10 })
		assert.is_true(splitjoin.toggle(bufnr))
		assert.is_true(#buffer_lines(bufnr) > 1)
		assert.is_true(splitjoin.toggle(bufnr))
		assert.same(original, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("restores the original cursor after a complete round-trip", function()
		local bufnr = create_buffer("x = foo(alpha, beta, gamma);", 1, 17)
		local original_cursor = vim.api.nvim_win_get_cursor(0)

		assert.is_true(splitjoin.toggle(bufnr))
		assert.is_true(splitjoin.toggle(bufnr))
		assert.same(original_cursor, vim.api.nvim_win_get_cursor(0))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("uses the buffer shiftwidth for generated continuation lines", function()
		local bufnr = create_buffer("x = foo(a, b, c);", 1, 10)
		vim.bo[bufnr].shiftwidth = 2

		assert.is_true(splitjoin.toggle(bufnr))
		assert.matches("^  b", buffer_lines(bufnr)[2])
		assert.matches("^  c", buffer_lines(bufnr)[3])
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("stays byte-stable under twenty toggles", function()
		local bufnr = create_buffer("x = foo(a, bar(b, c), [d, e]);", 1, 8)
		local original = buffer_lines(bufnr)
		for _ = 1, 20 do
			assert.is_true(splitjoin.toggle(bufnr))
		end
		assert.same(original, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not modify a single-item container", function()
		local bufnr = create_buffer("x = foo(a);", 1, 8)
		local before = buffer_lines(bufnr)

		assert.is_false(splitjoin.toggle(bufnr))
		assert.same(before, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not modify an unsupported statement", function()
		local bufnr = create_buffer("return", 1, 0)
		local before = buffer_lines(bufnr)

		assert.is_false(splitjoin.toggle(bufnr))
		assert.same(before, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("keeps the leader mapping on the cursor line at end of line", function()
		local first = "x = foo(a, b, c);"
		local second = "y = bar(d, e, f);"
		local bufnr = create_buffer(first .. "\n" .. second, 1, #first)

		vim.api.nvim_feedkeys(" s", "x", false)

		local lines = buffer_lines(bufnr)
		assert.are.equal("x = foo(a, ...", lines[1])
		assert.are.equal(second, lines[4])
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("joins the continued expression on the cursor line from indentation", function()
		local text = table.concat({
			"x = foo(a, b, c);",
			"y = bar(d, ...",
			"    e, f);",
		}, "\n")
		local bufnr = create_buffer(text, 2, 0)

		vim.api.nvim_feedkeys(" s", "x", false)

		assert.same({ "x = foo(a, b, c);", "y = bar(d, e, f);" }, buffer_lines(bufnr))
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not select an expression from another line on an empty line", function()
		local text = "x = foo(a, b, c);\n\ny = bar(d, e, f);"
		local bufnr = create_buffer(text, 2, 0)
		local before = buffer_lines(bufnr)
		local original_notify = vim.notify
		local notifications = 0
		vim.notify = function()
			notifications = notifications + 1
		end

		vim.api.nvim_feedkeys(" s", "x", false)
		vim.notify = original_notify

		assert.same(before, buffer_lines(bufnr))
		assert.are.equal(0, notifications)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)

	it("does not select adjacent expressions from an unsupported cursor line", function()
		local text = "x = foo(a, b, c);\nvalue = 1;\ny = bar(d, e, f);"
		local bufnr = create_buffer(text, 2, 3)
		local before = buffer_lines(bufnr)
		local original_notify = vim.notify
		local notifications = 0
		vim.notify = function()
			notifications = notifications + 1
		end

		vim.api.nvim_feedkeys(" s", "x", false)
		vim.notify = original_notify

		assert.same(before, buffer_lines(bufnr))
		assert.are.equal(0, notifications)
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end)
end)
