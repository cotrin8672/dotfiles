-- nvim --headless -u NONE -i NONE -n -c "lua dofile('tests/nvim_matlab_command_window.lua')"
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.showmode = false
package.loaded["config.matlab.core"] = {
	connection_state = function()
		return "connected", "R2024a"
	end,
}
local cmdwin = require("config.matlab.command_window")
local submitted, sessions = {}, {}
cmdwin.set_submit_callback(function(input, _, session_id)
	submitted[#submitted + 1] = input
	sessions[#sessions + 1] = session_id
	return true
end)
cmdwin.handle_prompt_change("READY", true)
cmdwin.open()

local function lines(expected)
	local actual = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	assert(vim.deep_equal(actual, expected), "Expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

local function input()
	return vim.fn.prompt_getinput(vim.api.nvim_get_current_buf())
end

local steps = {
	{ keys = "draft" },
	{
		check = function()
			cmdwin.handle_text("protected one\nprotected two\n", 0)
			lines({ "protected one", "protected two", ">> draft" })
		end,
		keys = "<Esc>ggdd",
	},
	{
		check = function()
			lines({ "protected one", "protected two", ">> draft" })
		end,
		keys = "Gdd",
	},
	{
		check = function()
			lines({ "protected one", "protected two", ">> draft" })
			assert(not vim.bo.modifiable, "Normal mode must protect the transcript and prompt")
		end,
		keys = "d0",
	},
	{
		check = function()
			lines({ "protected one", "protected two", ">> draft" })
		end,
		keys = "ggVGd",
	},
	{
		check = function()
			lines({ "protected one", "protected two", ">> draft" })
		end,
		keys = "<Esc>A<C-u><BS>seed<CR>",
	},
	{
		check = function()
			assert(vim.deep_equal(submitted, { "seed" }), vim.inspect(submitted))
			lines({ "protected one", "protected two", ">> seed", ">> " })
		end,
		keys = "<Esc>gg",
	},
	{
		check = function()
			assert(vim.api.nvim_paste("a=1;\r\nb=2;\r\n", true, -1))
		end,
	},
	{
		check = function()
			assert(#submitted == 1, "Pasting must not execute commands")
			lines({ "protected one", "protected two", ">> seed", ">> a=1;", "b=2;", "" })
			cmdwin.handle_text("arrived\n", 0)
			lines({ "protected one", "protected two", ">> seed", "arrived", ">> a=1;", "b=2;", "" })
			assert(input() == "a=1;\nb=2;\n", "Output must stay outside multiline input: " .. vim.inspect(input()))
		end,
		keys = "<Up>",
	},
	{
		check = function()
			assert(vim.api.nvim_win_get_cursor(0)[1] == 6, "Up must move inside multiline input")
		end,
		keys = "<Down>",
	},
	{
		check = function()
			assert(vim.api.nvim_win_get_cursor(0)[1] == 7, "Down must move inside multiline input")
			vim.api.nvim_win_set_cursor(0, { 5, 3 })
			cmdwin.handle_text("above draft\n", 0)
			assert(vim.api.nvim_win_get_cursor(0)[1] == 6, "Output must keep the cursor inside the draft")
		end,
		keys = "<Up>",
	},
	{
		check = function()
			assert(input() == "a=1;\nb=2;\n", "Prefix search must keep an unmatched draft")
		end,
		keys = "<Down><Down><Down>",
	},
	{
		check = function()
			assert(input() == "a=1;\nb=2;\n", "History must restore the multiline draft")
		end,
		keys = "<C-o>dd",
	},
	{
		check = function()
			assert(input() == "a=1;\nb=2;\n", "Temporary Normal mode must stay protected")
			assert(vim.bo.modifiable, "Returning to Insert mode must unlock input")
		end,
		keys = "<CR>",
	},
	{
		check = function()
			assert(vim.deep_equal(submitted, { "seed", "a=1;\nb=2;\n" }), vim.inspect(submitted))
			assert(vim.api.nvim_paste("a=1;\n", false, -1))
			local start = vim.api.nvim_buf_get_mark(0, ":")
			vim.api.nvim_win_set_cursor(0, start)
		end,
		keys = "<Up>",
	},
	{
		check = function()
			assert(input() == "a=1;\nb=2;\n", "History must recall the entire multiline command")
		end,
		keys = "<Down>",
	},
	{
		check = function()
			assert(input() == "a=1;\n", "History must restore the entire multiline draft")
		end,
		keys = "<CR>",
	},
	{
		check = function()
			assert(#submitted == 3 and submitted[3] == "a=1;\n")
			vim.fn.setreg("a", "z=3;\nz=4;", "v")
		end,
		keys = "<C-r>a",
	},
	{
		check = function()
			assert(#submitted == 3, "Insert register paste must not execute commands")
			assert(input() == "z=3;\nz=4;", vim.inspect(input()))
			local last = vim.api.nvim_buf_line_count(0)
			vim.api.nvim_win_set_cursor(0, { last, 2 })
			assert(vim.api.nvim_paste("A", false, 1))
			assert(vim.api.nvim_paste("B\n", false, 2))
			cmdwin.handle_text("during paste\n", 0)
			assert(vim.api.nvim_paste("C", false, 3))
			assert(input() == "z=3;\nz=AB\nC4;", "Streamed paste must keep the cursor and suffix")
			cmdwin.handle_clc()
			lines({ ">> z=3;", "z=AB", "C4;" })
			cmdwin.handle_text("failure\n", 1)
			lines({ "failure", ">> z=3;", "z=AB", "C4;" })
			local namespace = vim.api.nvim_get_namespaces().MatlabCommandWindowOutput
			local marks = vim.api.nvim_buf_get_extmarks(0, namespace, 0, -1, { details = true })
			assert(#marks == 1 and marks[1][2] == 0 and marks[1][4].hl_group == "ErrorMsg")
		end,
		keys = "<Esc>ggu",
	},
	{
		check = function()
			lines({ "failure", ">> z=3;", "z=AB", "C4;" })
		end,
		keys = "A<CR>",
	},
	{
		check = function()
			assert(#submitted == 4 and submitted[4] == "z=3;\nz=AB\nC4;")
			vim.fn.setreg("a", { "r=1;", "r=2;" }, "V")
		end,
		keys = '<Esc>gg"ap',
	},
	{
		check = function()
			assert(input() == "r=1;\nr=2;\n", "Linewise register paste must preserve all lines")
			assert(#submitted == 4, "Normal register paste must not execute commands")
		end,
		keys = "<CR>",
	},
	{
		check = function()
			assert(#submitted == 5 and submitted[5] == "r=1;\nr=2;\n")
			vim.fn.setreg("a", "selected\npaste", "v")
		end,
		keys = '<Esc>ggV"aP',
	},
	{
		check = function()
			assert(input() == "selected\npaste", "Visual paste must target the input")
			assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "failure", "Visual paste must keep output")
			assert(#submitted == 5)
		end,
		keys = "<CR>",
	},
	{
		check = function()
			assert(#submitted == 6 and submitted[6] == "selected\npaste")
			cmdwin.handle_prompt_change("BUSY", false)
			assert(not vim.bo.modifiable and not vim.api.nvim_paste("blocked", false, -1))
			cmdwin.handle_prompt_change("READY", true)
			assert(vim.api.nvim_paste("draft\nkept", false, -1))
			cmdwin.handle_text("early\n", 0, 2)
			cmdwin.select_session(2, 2, 2)
			cmdwin.handle_prompt_change("READY", true)
			cmdwin.open()
		end,
	},
	{
		check = function()
			lines({ "early", ">> " })
			cmdwin.handle_text("background\n", 0, 1)
			local first = cmdwin.buffer_for_session(1)
			assert(not vim.bo[first].modifiable, "Background session output must stay protected")
			assert(vim.api.nvim_paste("second\nsession", false, -1))
		end,
		keys = "<CR>",
	},
	{
		check = function()
			assert(#submitted == 7 and submitted[7] == "second\nsession" and sessions[7] == 2)
			cmdwin.select_session(1, 2, 1)
			cmdwin.open()
		end,
	},
	{
		check = function()
			assert(input() == "draft\nkept", "Session switching must preserve a multiline draft")
			cmdwin.close()
		end,
	},
	{
		check = function()
			assert(vim.bo.buftype == "" and vim.bo.modifiable)
			assert(vim.api.nvim_paste("ordinary\npaste", false, -1))
			lines({ "ordinary", "paste" })
		end,
	},
}
local index = 0
local function advance()
	local ok, err = pcall(function()
		index = index + 1
		local step = steps[index]
		if not step then
			print("MATLAB Command Window: protected output and multiline input passed")
			vim.cmd("qa!")
			return
		end
		if step.check then
			step.check()
		end
		if step.keys then
			vim.api.nvim_input(step.keys)
		end
		vim.defer_fn(advance, 100)
	end)
	if not ok then
		print("MATLAB Command Window failed at step " .. index .. ": " .. tostring(err))
		vim.cmd("cquit 1")
	end
end
vim.defer_fn(advance, 100)
