-- nvim --headless -u NONE -i NONE -n -c "lua dofile('tests/nvim_matlab_interrupt.lua')"
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.g.mapleader = " "
vim.opt.showmode = false
package.loaded["config.matlab.core"] = {
	connection_state = function()
		return "connected", "R2024a"
	end,
}
local cmdwin = require("config.matlab.command_window")
local calls = {}
cmdwin.set_interrupt_callback(function(session_id)
	calls[#calls + 1] = session_id
end)
cmdwin.handle_prompt_change("READY", true)
cmdwin.open()

local steps = {
	{
		check = function()
			assert(vim.api.nvim_get_mode().mode == "i", "Command Window must start in insert mode")
		end,
		keys = "<C-c>",
	},
	{
		check = function()
			assert(vim.deep_equal(calls, { 1 }), "Native insert Ctrl-C did not interrupt MATLAB")
			assert(vim.api.nvim_get_mode().mode == "i", "Ctrl-C must keep the prompt editable")
			cmdwin.handle_prompt_change("BUSY", false)
		end,
		keys = "<C-c>",
	},
	{
		check = function()
			assert(vim.deep_equal(calls, { 1, 1 }), "Ctrl-C must also interrupt a busy prompt")
		end,
		keys = "<Esc>",
	},
	{ keys = " mi" },
	{
		check = function()
			assert(vim.deep_equal(calls, { 1, 1, 1 }), "Command Window leader mi did not interrupt MATLAB")
		end,
		keys = "<C-c>",
		feed = true,
	},
	{
		check = function()
			assert(vim.deep_equal(calls, { 1, 1, 1, 1 }), "Normal Ctrl-C did not interrupt MATLAB")
			cmdwin.select_session(2, 2, 2)
			cmdwin.handle_prompt_change("READY", true)
			cmdwin.open()
		end,
		keys = "<C-c>",
	},
	{
		check = function()
			assert(calls[5] == 2 and #calls == 5, "Ctrl-C must target the visible Command Window session")
		end,
		keys = "<Esc>",
	},
	{ keys = " mi" },
	{
		check = function()
			assert(calls[6] == 2 and #calls == 6, "leader mi must target the visible Command Window session")
		end,
	},
}
local index = 0
local function advance()
	local ok, err = pcall(function()
		index = index + 1
		local step = steps[index]
		if not step then
			print("MATLAB interrupt: insert/normal Ctrl-C, leader mi, and session targets passed")
			vim.cmd("qa!")
			return
		end
		if step.check then
			step.check()
		end
		if step.keys then
			if step.feed then
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(step.keys, true, false, true), "t", false)
			else
				vim.api.nvim_input(step.keys)
			end
		end
		vim.defer_fn(advance, 150)
	end)
	if not ok then
		print("MATLAB interrupt failed at step " .. index .. ": " .. tostring(err))
		vim.cmd("cquit 1")
	end
end
vim.defer_fn(advance, 150)
