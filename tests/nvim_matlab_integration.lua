-- Run from the repository root (the native input loop must keep running):
-- nvim --headless -u NONE -i NONE -n -c "lua dofile('tests/nvim_matlab_integration.lua')"
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/site")
for _, plugin in ipairs({ "nvim-autopairs", "nvim-treesitter-endwise", "LuaSnip", "blink.lib", "blink.cmp" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
vim.g.mapleader = " "
vim.opt.expandtab, vim.opt.shiftwidth, vim.opt.tabstop, vim.opt.softtabstop = true, 4, 4, 4
vim.opt.autoindent, vim.opt.hidden, vim.opt.showmode = true, true, false
vim.opt.report = 9999
vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
require("luasnip").setup(require("plugins.luasnip").opts)
require("luasnip.loaders.from_lua").load({ paths = { config .. "/lua/snippets" } })
local opts = vim.deepcopy(require("plugins.blink").opts)
-- Keep the actual MATLAB provider filters/keymaps; isolate external sources and LSP startup.
opts.sources.default = { "snippets" }
opts.sources.providers = { snippets = opts.sources.providers.snippets }
opts.fuzzy = { implementation = "lua", frecency = { enabled = false }, use_proximity = false }
local blink = require("blink.cmp")
blink.setup(opts)
require("config.matlab.editing").setup()
local pairs = require("plugins.nvim-autopairs")
pairs.config(nil, pairs.opts)
local endwise = require("nvim-treesitter-endwise")
endwise.init()
assert(not endwise.is_supported("matlab"), "MATLAB must have only one end-completion handler")

local steps, cases = {}, 0
local name
local function scenario(label, initial, expandtab)
	name, cases = label, cases + 1
	table.insert(steps, {
		label = label .. ": setup",
		before = function()
			assert(vim.api.nvim_get_mode().mode == "n", "Previous scenario did not leave insert mode")
			blink.hide()
			local buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_set_current_buf(buf)
			vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/Integration.m")
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, initial or { "" })
			vim.bo.filetype = "matlab"
			vim.bo.indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
			vim.bo.expandtab = expandtab ~= false
		end,
	})
end
local function no_menu()
	assert(not blink.is_menu_visible(), "Unexpected snippet menu: " .. vim.inspect(blink.get_selected_item()))
end
local function step(keys, lines, cursor, check)
	lines = vim.deepcopy(lines)
	table.insert(steps, {
		label = name .. ": " .. keys,
		keys = keys,
		check = function()
			local actual = vim.api.nvim_buf_get_lines(0, 0, -1, false)
			assert(vim.deep_equal(actual, lines), "Expected " .. vim.inspect(lines) .. ", got " .. vim.inspect(actual))
			if cursor then
				assert(
					vim.deep_equal(vim.api.nvim_win_get_cursor(0), cursor),
					"Cursor: " .. vim.inspect(vim.api.nvim_win_get_cursor(0))
				)
			end
			if check then
				check()
			end
		end,
	})
end

scenario("accept if snippet and jump to body")
step("iif", { "if" }, { 1, 2 }, function()
	assert(blink.is_menu_visible() and blink.get_selected_item().label == "if", "if snippet is not selected")
end)
step("<CR>", { "if condition", "    ", "end" }, nil, function()
	assert(blink.snippet_active() and vim.api.nvim_get_mode().mode == "s", "Snippet condition is not selected")
end)
step("ready", { "if ready", "    ", "end" }, { 1, 8 }, no_menu)
step("<Tab>", { "if ready", "    ", "end" }, { 2, 4 })
step("body<CR>next<Esc>", { "if ready", "    body", "    next", "end" }, { 3, 7 }, no_menu)
step("u", { "if ready", "    ", "end" })
step("u", { "if condition", "    ", "end" })
step("<C-r>", { "if ready", "    ", "end" })
step("<C-r>", { "if ready", "    body", "    next", "end" })

scenario("queued snippet jump keeps explicit local undo settings")
local global_undo_levels = vim.go.undolevels
table.insert(steps, {
	before = function()
		vim.bo.undolevels = 2000
	end,
})
step("iif", { "if" })
step("<CR>", { "if condition", "    ", "end" })
step("ready", { "if ready", "    ", "end" }, { 1, 8 }, no_menu)
step("<Tab>body<CR>next<Esc>", { "if ready", "    body", "    next", "end" }, { 3, 7 }, function()
	assert(vim.bo.undolevels == 2000 and vim.go.undolevels == global_undo_levels, "Snippet jump changed undo settings")
end)
step("u", { "if ready", "    ", "end" })
step("u", { "if condition", "    ", "end" })
step("<C-r>", { "if ready", "    ", "end" })
step("<C-r>", { "if ready", "    body", "    next", "end" })

scenario("Enter after editing accepted condition")
step("iif", { "if" }, nil, function()
	assert(blink.is_menu_visible() and blink.get_selected_item().label == "if")
end)
step("<CR>", { "if condition", "    ", "end" })
step("ready", { "if ready", "    ", "end" }, { 1, 8 }, no_menu)
step("<CR>", { "if ready", "    ", "    ", "end" }, { 2, 4 }, no_menu)
step("body<Esc>", { "if ready", "    body", "    ", "end" }, { 2, 7 })

scenario("backward snippet jump keeps separate undo blocks")
step("iif", { "if" })
step("<CR>", { "if condition", "    ", "end" })
step("ready", { "if ready", "    ", "end" })
step("<Tab>one", { "if ready", "    one", "end" }, { 2, 7 })
step("<S-Tab>", { "if ready", "    one", "end" }, nil, function()
	assert(vim.api.nvim_get_mode().mode == "s", "Backward jump did not select the condition")
end)
step("other<Esc>", { "if other", "    one", "end" })
step("u", { "if ready", "    one", "end" })
step("u", { "if ready", "    ", "end" })
step("<C-r>", { "if ready", "    one", "end" })
step("<C-r>", { "if other", "    one", "end" })

for _, header in ipairs({ "if(ready)", "if (ready)" }) do
	scenario("rapid completed " .. header)
	step("i" .. header, { header }, { 1, #header }, no_menu)
	step("<CR>", { header, "    ", "end" }, { 2, 4 }, no_menu)
	step("body<Esc>", { header, "    body", "end" }, { 2, 7 })
end

for _, header in ipairs({ "foo(", "function y = f(" }) do
	scenario("empty paired " .. header)
	step("i" .. header, { header .. ")" }, { 1, #header }, no_menu)
	step("<CR>", { header .. " ...", "     ...", ")" }, { 2, 4 }, no_menu)
	step("a,", { header .. " ...", "    a, ...", ")" }, { 2, 6 }, no_menu)
	step("<CR>", { header .. " ...", "    a, ...", "     ...", ")" }, { 3, 4 }, no_menu)
	step("b", { header .. " ...", "    a, ...", "    b ...", ")" }, { 3, 5 }, no_menu)
	step("<CR>", { header .. " ...", "    a, ...", "    b ...", ")" }, { 4, 0 }, no_menu)
	step(")", { header .. " ...", "    a, ...", "    b ...", ")" }, { 4, 1 }, no_menu)
	local final = { header .. " ...", "    a, ...", "    b ...", ")", header:match("^function") and "    " or "" }
	if header:match("^function") then
		table.insert(final, "end")
	end
	step("<CR>", final, { 5, #final[5] }, no_menu)
	final[5] = final[5] .. "value = 1;"
	step("value = 1;<Esc>", final, nil, no_menu)
end

for _, header in ipairs({ "foo(a,", "function y = f(a," }) do
	scenario("nonempty paired " .. header)
	step("i" .. header, { header .. ")" }, { 1, #header }, no_menu)
	step("<CR>", { header .. " ...", "     ...", ")" }, { 2, 4 }, no_menu)
	step("b", { header .. " ...", "    b ...", ")" }, { 2, 5 }, no_menu)
	step("<CR>", { header .. " ...", "    b ...", ")" }, { 3, 0 }, no_menu)
	step(")", { header .. " ...", "    b ...", ")" }, { 3, 1 }, no_menu)
	local final = { header .. " ...", "    b ...", ")", header:match("^function") and "    " or "" }
	if header:match("^function") then
		table.insert(final, "end")
	end
	step("<CR>", final, { 4, #final[4] }, no_menu)
	final[4] = final[4] .. "value = 1;"
	step("value = 1;<Esc>", final, nil, no_menu)
end

for _, header in ipairs({ "a = [", "a = [1 2", "a = [1 2;" }) do
	scenario("matrix " .. header)
	step("i" .. header, { header .. "]" }, { 1, #header }, no_menu)
	local first = header .. (header:sub(-1) == ";" and "" or " ...")
	step("<CR>", { first, "     ...", "]" }, { 2, 4 }, no_menu)
	step("3 4", { first, "    3 4 ...", "]" }, { 2, 7 }, no_menu)
	step("<CR>", { first, "    3 4 ...", "]" }, { 3, 0 }, no_menu)
	step("]", { first, "    3 4 ...", "]" }, { 3, 1 }, no_menu)
	step(";<CR>value = 1;<Esc>", { first, "    3 4 ...", "];", "value = 1;" }, { 4, 9 }, no_menu)
end

for _, base in ipairs({ "", "    ", "\t" }) do
	local unit = base == "\t" and "\t" or "    "
	scenario("nested native dot, undo and redo at " .. vim.inspect(base), { base, base }, base ~= "\t")
	local block = {
		base .. "if outer",
		base .. unit .. "for k = 1:3",
		base .. unit .. unit .. "while ready",
		base .. unit .. unit .. unit .. "body",
		base .. unit .. unit .. "end",
		base .. unit .. "end",
		base .. "end",
	}
	local original = vim.list_extend(vim.deepcopy(block), { base })
	step("Aif outer<CR>for k = 1:3<CR>while ready<CR>body<Esc>", original, { 4, #block[4] - 1 }, no_menu)
	step("G$", original, { 8, math.max(0, #base - 1) })
	local repeated = vim.list_extend(vim.deepcopy(block), block)
	step(".", repeated, { 11, #block[4] - 1 }, no_menu)
	step("u", original, nil)
	step("<C-r>", repeated, nil)
end

scenario("dot into a block with an existing end", { "if ready", "end", "", "if other", "end" })
step("A<CR>one<Esc>", { "if ready", "    one", "end", "", "if other", "end" }, { 2, 6 })
step("5G$", { "if ready", "    one", "end", "", "if other", "end" }, { 5, 7 })
step(".", { "if ready", "    one", "end", "", "if other", "    one", "end" }, { 6, 6 })
step("u", { "if ready", "    one", "end", "", "if other", "end" })
step("<C-r>", { "if ready", "    one", "end", "", "if other", "    one", "end" })

local index, input_steps = 0, 0
local function advance()
	local ok, err = pcall(function()
		if steps[index] and steps[index].check then
			steps[index].check()
		end
		index = index + 1
		local next_step = steps[index]
		if not next_step then
			print(("MATLAB integration: %d scenarios, %d native input steps passed"):format(cases, input_steps))
			vim.cmd("qa!")
			return
		end
		if next_step.before then
			next_step.before()
		end
		if next_step.keys then
			input_steps = input_steps + 1
			vim.api.nvim_input(next_step.keys)
		end
		vim.defer_fn(advance, 150)
	end)
	if not ok then
		print(
			"MATLAB integration failed at " .. (steps[index] and steps[index].label or "setup") .. ": " .. tostring(err)
		)
		vim.cmd("cquit 1")
	end
end
vim.defer_fn(advance, 0)
