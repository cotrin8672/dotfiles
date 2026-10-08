-- Run from the repository root: nvim --headless -u NONE -i NONE -n -l tests/nvim_matlab_splitjoin.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
local splitjoin = require("config.matlab.splitjoin")
vim.g.mapleader = " "
vim.keymap.set("n", "<leader>s", require("plugins.treesj").keys[1][2])
local cases = 0
local notifications = {}
vim.notify = function(message)
	table.insert(notifications, message)
end

local function with_buffer(lines, cursor, callback, options)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)
	vim.bo[buf].filetype = "matlab"
	vim.bo[buf].shiftwidth = options and options.shiftwidth or 4
	vim.bo[buf].tabstop = options and options.tabstop or 4
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_win_set_cursor(0, cursor or { 1, 0 })
	callback(buf)
	vim.api.nvim_buf_delete(buf, { force = true })
	cases = cases + 1
end

local function assert_text(buf, expected)
	local actual = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	assert(vim.deep_equal(actual, expected), "Expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

-- Keep row/statement structure, operators, string bytes and every named token;
-- ignore layout continuations and interchangeable list/row separators.
local function syntax(buf)
	local root = vim.treesitter.get_parser(buf, "matlab"):parse(true)[1]:root()
	local function shape(node)
		assert(not node:missing() and node:type() ~= "ERROR", "Invalid MATLAB syntax: " .. root:sexpr())
		if node:type() == "line_continuation" or node:type() == "," or node:type() == ";" or node:type() == "\n" then
			return nil
		end
		local children = {}
		for child in node:iter_children() do
			local value = shape(child)
			if value then
				table.insert(children, value)
			end
		end
		return { node:type(), #children > 0 and children or vim.treesitter.get_node_text(node, buf) }
	end
	return shape(root)
end

local function roundtrip(lines, expected, cursor, generated_cursor, options)
	with_buffer(lines, cursor, function(buf)
		local original_cursor = vim.api.nvim_win_get_cursor(0)
		local original_syntax = syntax(buf)
		for _ = 1, 2 do
			assert(splitjoin.toggle(), "Supported expression must toggle: " .. table.concat(lines, "\n"))
			assert_text(buf, expected)
			assert(vim.deep_equal(syntax(buf), original_syntax), "Split/join changed MATLAB syntax")
			if generated_cursor then
				assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), generated_cursor), "Wrong generated cursor")
			end
			assert(splitjoin.toggle(), "Saved state must toggle back")
			assert_text(buf, lines)
			assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), original_cursor), "Roundtrip must restore the cursor")
		end
	end, options)
end

local function canonicalize(lines, joined, split, cursor, options)
	with_buffer(lines, cursor, function(buf)
		local original_syntax = syntax(buf)
		for _, expected in ipairs({ joined, split, joined, split }) do
			assert(splitjoin.toggle(), "Existing wrapping must toggle into canonical layout")
			assert_text(buf, expected)
			assert(vim.deep_equal(syntax(buf), original_syntax), "Canonical split/join changed MATLAB syntax")
		end
	end, options)
end

local function mapped_toggle_at(buf, token, offset, expected)
	local original_syntax = syntax(buf)
	for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local col = line:find(token, 1, true)
		if col then
			vim.api.nvim_win_set_cursor(0, { row, col - 1 + offset })
			vim.api.nvim_feedkeys(" s", "mx", false)
			assert_text(buf, expected)
			assert(vim.deep_equal(syntax(buf), original_syntax), "Mapped split/join changed MATLAB syntax")
			local cursor = vim.api.nvim_win_get_cursor(0)
			vim.bo[buf].expandtab = true
			vim.bo[buf].indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
			vim.cmd("silent normal! gg=G")
			assert_text(buf, expected)
			vim.api.nvim_win_set_cursor(0, cursor)
			return
		end
	end
	error("Missing cursor token: " .. token)
end

local declaration = {
	"function [A_comb_power, B_comb_power] = run_main_detuning_sweep_off_point(cycle, At_in, aux_off_detuning)",
	"end",
}
local split_declaration = {
	"function [A_comb_power, B_comb_power] = run_main_detuning_sweep_off_point( ...",
	"    cycle, ...",
	"    At_in, ...",
	"    aux_off_detuning ...",
	")",
	"end",
}
roundtrip(declaration, split_declaration, { 1, 70 }, { 2, 4 })
roundtrip(split_declaration, declaration, { 5, 0 })
roundtrip({ "function y = f(arg)", "end" }, { "function y = f( ...", "    arg ...", ")", "end" })
roundtrip({ "function f(a, b)", "end" }, { "function f( ...", "    a, ...", "    b ...", ")", "end" })
roundtrip({ "function varargout = f(varargin)", "end" }, {
	"function varargout = f( ...",
	"    varargin ...",
	")",
	"end",
})
roundtrip({ "    function y = f(a, b) % header", "    end" }, {
	"    function y = f( ...",
	"        a, ...",
	"        b ...",
	"    ) % header",
	"    end",
})
roundtrip({ "function y = f( a ,  b )", "end" }, { "function y = f( ...", "    a, ...", "    b ...", ")", "end" })
roundtrip({ "function ...", "    y = f(a, b)", "end" }, {
	"function ...",
	"    y = f( ...",
	"        a, ...",
	"        b ...",
	"    )",
	"end",
}, { 2, 8 })

local call = { "value = f(a, b);" }
local split_call = { "value = f( ...", "    a, ...", "    b ...", ");" }
roundtrip(call, split_call, { 1, 8 }, { 2, 4 })
for _, cursor in ipairs({ { 1, 8 }, { 2, 4 }, { 3, 4 }, { 4, 0 } }) do
	roundtrip(split_call, call, cursor, { 1, 10 })
end
roundtrip({ "value = f(a);" }, { "value = f( ...", "    a ...", ");" })
roundtrip({ "    f(a, b); % tail" }, { "    f( ...", "        a, ...", "        b ...", "    ); % tail" })
roundtrip({ "\tf(a, b);" }, { "\tf( ...", "\t  a, ...", "\t  b ...", "\t);" }, nil, { 2, 3 }, { shiftwidth = 2 })
roundtrip({ "f(a, b);" }, { "f( ...", "   a, ...", "   b ...", ");" }, nil, nil, { shiftwidth = 0, tabstop = 3 })
roundtrip({ "f( a ,  b );" }, { "f( ...", "    a, ...", "    b ...", ");" })
canonicalize({ "f(a, ...", "    b);" }, { "f(a, b);" }, { "f( ...", "    a, ...", "    b ...", ");" })
canonicalize({ "f( ...", "    a, ...", "    b);" }, { "f(a, b);" }, { "f( ...", "    a, ...", "    b ...", ");" })
canonicalize({ "f(a, b ...", ");" }, { "f(a, b);" }, { "f( ...", "    a, ...", "    b ...", ");" })
canonicalize({ "function [x, y] = f(a, b, ...", "    c, d) % header", "end" }, {
	"function [x, y] = f(a, b, c, d) % header",
	"end",
}, {
	"function [x, y] = f( ...",
	"    a, ...",
	"    b, ...",
	"    c, ...",
	"    d ...",
	") % header",
	"end",
}, { 1, 18 })
canonicalize({ "value = f(g(a, b, ...", "    c, d), [1 2; 3 4]); % tail" }, {
	"value = f(g(a, b, c, d), [1 2; 3 4]); % tail",
}, {
	"value = f(g( ...",
	"    a, ...",
	"    b, ...",
	"    c, ...",
	"    d ...",
	"), [1 2; 3 4]); % tail",
}, { 1, 10 })
canonicalize({ "value = f([1 2; ...", "    3 4], tail);" }, { "value = f([1 2; 3 4], tail);" }, {
	"value = f([1 ...",
	"    2; ...",
	"    3 ...",
	"    4], tail);",
}, { 1, 10 })
canonicalize({ "f('it''s %, ...', A', ...", '    B.\', "x,%", {1, 2; 3, 4}); % tail' }, {
	"f('it''s %, ...', A', B.', \"x,%\", {1, 2; 3, 4}); % tail",
}, {
	"f( ...",
	"    'it''s %, ...', ...",
	"    A', ...",
	"    B.', ...",
	'    "x,%", ...',
	"    {1, 2; 3, 4} ...",
	"); % tail",
})

-- Native Undo owns the original manual wrapping; toggles own the canonical layout.
local manual_run_lle = {
	"store;",
	"run_lle = store.recompute(@solve_lle, waveform);",
	"",
	"[At_in, Bt_in] = run_lle( ...",
	"    cycle, At_in, Bt_in, stepTime_normal, Kappa_normal, disp_normal, ...",
	"    interaction, detuning_main, detuning_aux, Gamma_normal, ...",
	"    F_main, F_aux, u, Raman_coef, aux_pump_mode, noise_str, interaction_coef);",
}
local joined_run_lle = {
	manual_run_lle[1],
	manual_run_lle[2],
	"",
	"[At_in, Bt_in] = run_lle(cycle, At_in, Bt_in, stepTime_normal, Kappa_normal, disp_normal, interaction, detuning_main, detuning_aux, Gamma_normal, F_main, F_aux, u, Raman_coef, aux_pump_mode, noise_str, interaction_coef);",
}
local canonical_run_lle = {
	manual_run_lle[1],
	manual_run_lle[2],
	"",
	"[At_in, Bt_in] = run_lle( ...",
	"    cycle, ...",
	"    At_in, ...",
	"    Bt_in, ...",
	"    stepTime_normal, ...",
	"    Kappa_normal, ...",
	"    disp_normal, ...",
	"    interaction, ...",
	"    detuning_main, ...",
	"    detuning_aux, ...",
	"    Gamma_normal, ...",
	"    F_main, ...",
	"    F_aux, ...",
	"    u, ...",
	"    Raman_coef, ...",
	"    aux_pump_mode, ...",
	"    noise_str, ...",
	"    interaction_coef ...",
	");",
}
with_buffer(manual_run_lle, { 4, 21 }, function(buf)
	local original_syntax = syntax(buf)
	for _, expected in ipairs({ joined_run_lle, canonical_run_lle }) do
		vim.api.nvim_feedkeys(" s", "xt", false)
		assert_text(buf, expected)
		assert(vim.deep_equal(syntax(buf), original_syntax), "Native toggle changed run_lle arguments")
	end
	vim.api.nvim_feedkeys("u", "xt", false)
	assert_text(buf, joined_run_lle)
	vim.api.nvim_feedkeys("u", "xt", false)
	assert_text(buf, manual_run_lle)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-r>", true, false, true), "xt", false)
	assert_text(buf, joined_run_lle)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-r>", true, false, true), "xt", false)
	assert_text(buf, canonical_run_lle)
	mapped_toggle_at(buf, "run_lle(", 1, joined_run_lle)
	mapped_toggle_at(buf, "run_lle(", 1, canonical_run_lle)
end)
roundtrip({ "obj.method(a, b);" }, { "obj.method( ...", "    a, ...", "    b ...", ");" })
roundtrip({ "value = A(1:end, :);" }, { "value = A( ...", "    1:end, ...", "    : ...", ");" }, { 1, 8 })
roundtrip({ "value = f(A(1:end), g('a,b', matrix.'), \"x,%\");" }, {
	"value = f( ...",
	"    A(1:end), ...",
	"    g('a,b', matrix.'), ...",
	'    "x,%" ...',
	");",
}, { 1, 8 })
roundtrip({ "value = f('it''s %, ...', A', B.', \"a,b\", {1, 2; 3, 4});" }, {
	"value = f( ...",
	"    'it''s %, ...', ...",
	"    A', ...",
	"    B.', ...",
	'    "a,b", ...',
	"    {1, 2; 3, 4} ...",
	");",
}, { 1, 8 })
roundtrip({ "value = f([a b; c d], {x, y}, @(a, b) a + b);" }, {
	"value = f( ...",
	"    [a b; c d], ...",
	"    {x, y}, ...",
	"    @(a, b) a + b ...",
	");",
}, { 1, 8 })
roundtrip({ "value = f(g( ...", "    a, ...", "    b ...", "), c);" }, {
	"value = f( ...",
	"    g( ...",
	"        a, ...",
	"        b ...",
	"    ), ...",
	"    c ...",
	");",
}, { 1, 8 })
roundtrip({ "value = f( ...", "    g( ...", "        a, ...", "        b ...", "    ), ...", "    c ...", ");" }, {
	"value = f(g( ...",
	"    a, ...",
	"    b ...",
	"), c);",
}, { 1, 8 })

-- Saved outer ranges must never take over the selected nested call or index.
local nested_call = { "value = f(g(a, b), c);" }
local outer_split = { "value = f( ...", "    g(a, b), ...", "    c ...", ");" }
local both_split = {
	"value = f( ...",
	"    g( ...",
	"        a, ...",
	"        b ...",
	"    ), ...",
	"    c ...",
	");",
}
with_buffer(nested_call, nil, function(buf)
	for _, offset in ipairs({ 0, 1 }) do
		mapped_toggle_at(buf, "f(", 1, outer_split)
		mapped_toggle_at(buf, "g(", offset, both_split)
		mapped_toggle_at(buf, "), ...", 0, outer_split)
		mapped_toggle_at(buf, ");", 0, nested_call)
	end
end)
with_buffer(nested_call, nil, function(buf)
	mapped_toggle_at(buf, "f(", 1, outer_split)
	mapped_toggle_at(buf, "g(", 1, both_split)
	mapped_toggle_at(buf, "f(", 1, {
		"value = f(g( ...",
		"    a, ...",
		"    b ...",
		"), c);",
	})
	mapped_toggle_at(buf, "), c);", 0, nested_call)
	mapped_toggle_at(buf, "f(", 1, outer_split)
end)
with_buffer(nested_call, nil, function(buf)
	mapped_toggle_at(buf, "g(", 1, { "value = f(g( ...", "    a, ...", "    b ...", "), c);" })
	mapped_toggle_at(buf, "f(", 1, both_split)
	mapped_toggle_at(buf, "), ...", 0, outer_split)
	mapped_toggle_at(buf, ");", 0, nested_call)
end)
with_buffer(nested_call, nil, function(buf)
	mapped_toggle_at(buf, "f(", 1, outer_split)
	mapped_toggle_at(buf, "g(", 1, both_split)
	vim.api.nvim_buf_set_lines(buf, 3, 4, false, { "        changed ..." })
	mapped_toggle_at(buf, "g(", 1, { "value = f( ...", "    g(a, changed), ...", "    c ...", ");" })
	mapped_toggle_at(buf, ");", 0, { "value = f(g(a, changed), c);" })
	mapped_toggle_at(buf, "f(", 1, { "value = f( ...", "    g(a, changed), ...", "    c ...", ");" })
end)
with_buffer({ "value = f(A(g(1), :), (a + b));" }, nil, function(buf)
	mapped_toggle_at(buf, "f(", 1, { "value = f( ...", "    A(g(1), :), ...", "    (a + b) ...", ");" })
	mapped_toggle_at(buf, "A(", 1, {
		"value = f( ...",
		"    A( ...",
		"        g(1), ...",
		"        : ...",
		"    ), ...",
		"    (a + b) ...",
		");",
	})
	mapped_toggle_at(buf, "g(", 1, {
		"value = f( ...",
		"    A( ...",
		"        g( ...",
		"            1 ...",
		"        ), ...",
		"        : ...",
		"    ), ...",
		"    (a + b) ...",
		");",
	})
	mapped_toggle_at(buf, "g(", 1, {
		"value = f( ...",
		"    A( ...",
		"        g(1), ...",
		"        : ...",
		"    ), ...",
		"    (a + b) ...",
		");",
	})
	mapped_toggle_at(buf, "A(", 1, { "value = f( ...", "    A(g(1), :), ...", "    (a + b) ...", ");" })
	mapped_toggle_at(buf, ");", 0, { "value = f(A(g(1), :), (a + b));" })
end)
with_buffer({ "value = f(g(h('a, )', \"x...\"), b), c);" }, nil, function(buf)
	local deepest_split = { "value = f(g(h( ...", "    'a, )', ...", '    "x..." ...', "), b), c);" }
	mapped_toggle_at(buf, "h(", 1, deepest_split)
	mapped_toggle_at(buf, "g(", 1, {
		"value = f(g( ...",
		"    h( ...",
		"        'a, )', ...",
		'        "x..." ...',
		"    ), ...",
		"    b ...",
		"), c);",
	})
	mapped_toggle_at(buf, "f(", 1, {
		"value = f( ...",
		"    g( ...",
		"        h( ...",
		"            'a, )', ...",
		'            "x..." ...',
		"        ), ...",
		"        b ...",
		"    ), ...",
		"    c ...",
		");",
	})
	mapped_toggle_at(buf, "g(", 1, {
		"value = f( ...",
		"    g(h( ...",
		"        'a, )', ...",
		'        "x..." ...',
		"    ), b), ...",
		"    c ...",
		");",
	})
	mapped_toggle_at(buf, "f(", 1, deepest_split)
	mapped_toggle_at(buf, "h(", 1, { "value = f(g(h('a, )', \"x...\"), b), c);" })
end)
with_buffer({ "value = f(g(a, b), h(c, d));" }, nil, function(buf)
	mapped_toggle_at(buf, "h(", 1, { "value = f(g(a, b), h( ...", "    c, ...", "    d ...", "));" })
	mapped_toggle_at(buf, "f(", 1, {
		"value = f( ...",
		"    g(a, b), ...",
		"    h( ...",
		"        c, ...",
		"        d ...",
		"    ) ...",
		");",
	})
	mapped_toggle_at(buf, "g(", 1, {
		"value = f( ...",
		"    g( ...",
		"        a, ...",
		"        b ...",
		"    ), ...",
		"    h( ...",
		"        c, ...",
		"        d ...",
		"    ) ...",
		");",
	})
	mapped_toggle_at(buf, "f(", 1, {
		"value = f(g( ...",
		"    a, ...",
		"    b ...",
		"), h( ...",
		"    c, ...",
		"    d ...",
		"));",
	})
	mapped_toggle_at(buf, "g(", 1, { "value = f(g(a, b), h( ...", "    c, ...", "    d ...", "));" })
	mapped_toggle_at(buf, "h(", 1, { "value = f(g(a, b), h(c, d));" })
end)
with_buffer({ "value = f((a + b), g(c, d));" }, nil, function(buf)
	local group_split = { "value = f((a + ...", "    b), g(c, d));" }
	local children_split = {
		"value = f((a + ...",
		"    b), g( ...",
		"        c, ...",
		"        d ...",
		"    ));",
	}
	mapped_toggle_at(buf, "(a +", 0, group_split)
	mapped_toggle_at(buf, "g(", 1, children_split)
	mapped_toggle_at(buf, "f(", 1, {
		"value = f( ...",
		"    (a + ...",
		"        b), ...",
		"    g( ...",
		"        c, ...",
		"        d ...",
		"    ) ...",
		");",
	})
	mapped_toggle_at(buf, "f(", 1, children_split)
	mapped_toggle_at(buf, "g(", 1, group_split)
	mapped_toggle_at(buf, "+ ...", 0, { "value = f((a + b), g(c, d));" })
end)
roundtrip({ "f(g( ...", "  a, ...", "  b ...", "), c);" }, {
	"f( ...",
	"  g( ...",
	"    a, ...",
	"    b ...",
	"  ), ...",
	"  c ...",
	");",
}, { 1, 1 }, nil, { shiftwidth = 2 })
roundtrip({ "baseRunner = @() run_lle(cycle, At_in, Bt_in);" }, {
	"baseRunner = @() run_lle( ...",
	"    cycle, ...",
	"    At_in, ...",
	"    Bt_in ...",
	");",
}, { 1, 23 })

-- Explicit grouping keeps a binary target inside its nearest parentheses.
for _, cursor in ipairs({ { 1, 4 }, { 1, 5 }, { 1, 10 } }) do
	roundtrip({ "x = (a + b) * (c + d);" }, { "x = (a + ...", "    b) * (c + d);" }, cursor)
end
roundtrip({ "x = (a + b) * (c + d);" }, { "x = (a + b) * ...", "    (c + d);" }, { 1, 12 })
roundtrip({ "x = ((a + b)) * c;" }, { "x = ((a + ...", "    b)) * c;" }, { 1, 4 })
roundtrip({ "f((a + b), c);" }, { "f((a + ...", "    b), c);" }, { 1, 2 })
roundtrip({ "f((a + b), c);" }, { "f( ...", "    (a + b), ...", "    c ...", ");" }, { 1, 1 })
roundtrip({ "x = (g(a, b)) * c;" }, { "x = (g( ...", "    a, ...", "    b ...", ")) * c;" }, { 1, 4 })
roundtrip({ "x = (1:5) * z;" }, { "x = (1: ...", "    5) * z;" }, { 1, 4 })
with_buffer({ "f(((a + b) * c), d);" }, nil, function(buf)
	mapped_toggle_at(buf, "f(", 1, { "f( ...", "    ((a + b) * c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, "(a + b)", 0, { "f( ...", "    ((a + ...", "        b) * c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, "* c", 0, {
		"f( ...",
		"    ((a + ...",
		"        b) * ...",
		"        c), ...",
		"    d ...",
		");",
	})
	mapped_toggle_at(buf, "* ...", 0, { "f( ...", "    ((a + ...", "        b) * c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, "+ ...", 0, { "f( ...", "    ((a + b) * c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, ");", 0, { "f(((a + b) * c), d);" })
end)
with_buffer({ "f((g(a, b) + c), d);" }, nil, function(buf)
	mapped_toggle_at(buf, "f(", 1, { "f( ...", "    (g(a, b) + c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, "(g(", 0, { "f( ...", "    (g(a, b) + ...", "        c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, "g(", 1, {
		"f( ...",
		"    (g( ...",
		"        a, ...",
		"        b ...",
		"    ) + ...",
		"        c), ...",
		"    d ...",
		");",
	})
	mapped_toggle_at(buf, ") +", 0, { "f( ...", "    (g(a, b) + ...", "        c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, "+ ...", 0, { "f( ...", "    (g(a, b) + c), ...", "    d ...", ");" })
	mapped_toggle_at(buf, ");", 0, { "f((g(a, b) + c), d);" })
end)

-- Keep the established layouts of other MATLAB expressions.
roundtrip({ "function [x, y] = f(a, b)", "end" }, { "function [x, ...", "    y] = f(a, b)", "end" }, { 1, 14 })
roundtrip({ "handler = @(a, b) f(a, b);" }, { "handler = @(a, ...", "    b) f(a, b);" }, { 1, 13 })
roundtrip({ "value = [one two; three four];" }, { "value = [one ...", "    two; ...", "    three ...", "    four];" })
roundtrip({ "value = [1, 2; 3, 4];" }, { "value = [1, ...", "    2; ...", "    3, ...", "    4];" })
roundtrip(
	{ "value = {one, two; three, four};" },
	{ "value = {one, ...", "    two; ...", "    three, ...", "    four};" }
)
canonicalize({ "value = [1 2", "    3 4];" }, { "value = [1 2; 3 4];" }, {
	"value = [1 ...",
	"    2; ...",
	"    3 ...",
	"    4];",
})
roundtrip({ "value = first + second * third;" }, { "value = first + ...", "    second * third;" }, { 1, 8 })

-- A remembered input toggle must not take over an explicit output selection.
with_buffer({ "function [x, y] = f(a, b)", "end" }, { 1, 19 }, function(buf)
	assert(splitjoin.toggle())
	assert(splitjoin.toggle())
	vim.api.nvim_win_set_cursor(0, { 1, 11 })
	assert(splitjoin.toggle())
	assert_text(buf, { "function [x, ...", "    y] = f(a, b)", "end" })
	assert(splitjoin.toggle())
	assert_text(buf, { "function [x, y] = f(a, b)", "end" })
end)
with_buffer({ "f(a, b); g(c, d);" }, { 1, 0 }, function(buf)
	assert(splitjoin.toggle())
	assert(splitjoin.toggle())
	vim.api.nvim_win_set_cursor(0, { 1, 9 })
	assert(splitjoin.toggle())
	assert_text(buf, { "f(a, b); g( ...", "    c, ...", "    d ...", ");" })
end)
with_buffer({ "function [x, y] = f(a, b)", "end" }, { 1, 11 }, function(buf)
	assert(splitjoin.toggle())
	assert(splitjoin.toggle())
	vim.api.nvim_win_set_cursor(0, { 1, 18 })
	assert(splitjoin.toggle())
	assert_text(buf, { "function [x, y] = f( ...", "    a, ...", "    b ...", ")", "end" })
end)

-- Edits inside a saved range invalidate it instead of resurrecting stale arguments.
with_buffer(call, { 1, 8 }, function(buf)
	assert(splitjoin.toggle())
	vim.api.nvim_buf_set_lines(buf, 1, 2, false, { "    changed, ..." })
	vim.api.nvim_win_set_cursor(0, { 2, 4 })
	assert(splitjoin.toggle())
	assert_text(buf, { "value = f(changed, b);" })
	assert(splitjoin.toggle())
	assert_text(buf, { "value = f( ...", "    changed, ...", "    b ...", ");" })
end)
with_buffer(call, { 1, 8 }, function(buf)
	assert(splitjoin.toggle())
	vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "% inserted above" })
	vim.api.nvim_win_set_cursor(0, { 5, 0 })
	assert(splitjoin.toggle())
	assert_text(buf, { "% inserted above", call[1] })
end)

local function rejected(lines, cursor, comment_or_error)
	with_buffer(lines, cursor, function(buf)
		local original_cursor = vim.api.nvim_win_get_cursor(0)
		local count = #notifications
		assert(not splitjoin.toggle(), "Unsafe or unsupported expression must be left alone")
		assert_text(buf, lines)
		assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), original_cursor), "Rejected toggle moved the cursor")
		if comment_or_error then
			assert(
				#notifications == count + 1 and notifications[#notifications]:find("comment or syntax error", 1, true)
			)
		end
	end)
end
rejected({ "f();" })
rejected({ "function f()", "end" })
rejected({ "function f", "end" })
rejected({ "% f(a, b)" })
rejected({ "plain_identifier" })
rejected({ "function y = f(a, b", "end" }, nil, true)
rejected({ "f(a, b;" }, nil, true)
rejected({ "f(a,, b);" }, nil, true)
rejected({ "function y = f(a,, b)", "end" }, nil, true)
rejected({ "f(a,", "    b);" }, nil, true)
rejected({ "f(a, ... % comment", "    b);" }, nil, true)
rejected({ "f(a, ... implicit comment", "    b);" }, nil, true)
rejected({ "f( ... leading comment", "    a, ...", "    b ...", ");" }, nil, true)
rejected({ "f( ...", "    a, ...", "    b ... trailing comment", ");" }, { 4, 0 }, true)
rejected({ "function y = f( ... leading comment", "    a, ...", "    b ...", ")", "end" }, nil, true)
rejected({ "function y = f(a, ...", "    b ... % trailing comment", ")", "end" }, { 3, 0 }, true)
rejected({ "value = [a, ... % comment", "    b];" }, nil, true)
rejected({ "f(a,", "    % preserved comment", "    b);" }, nil, true)

print(
	"PASS: "
		.. cases
		.. " MATLAB split/join cases, syntax structure, comments, cursor selection, canonical wrapping and exact roundtrips"
)
