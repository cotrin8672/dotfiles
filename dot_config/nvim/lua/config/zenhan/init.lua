local M = {}

local running = false
local pending = false
local command_available = nil

local function is_available(opts)
	if command_available == nil then
		command_available = vim.fn.executable(opts.command) == 1
		if not command_available then
			vim.notify_once("zenhan.exe not found", vim.log.levels.ERROR)
		end
	end

	return command_available
end

local function zenhan_off(opts)
	if not is_available(opts) then
		return
	end

	if running then
		pending = true
		return
	end

	running = true
	local ok, err = pcall(function()
		vim.system({ opts.command, opts.off_arg }, {
			stdout = false,
			stderr = false,
		}, function()
			running = false

			if pending then
				pending = false
				vim.schedule(function()
					zenhan_off(opts)
				end)
			end
		end)
	end)

	if not ok then
		running = false
		vim.notify_once(("failed to start zenhan.exe: %s"):format(err), vim.log.levels.ERROR)
	end
end

function M.setup(opts)
	local group = vim.api.nvim_create_augroup("zenhan", {
		clear = true,
	})

	vim.api.nvim_create_autocmd({
		"VimEnter",
		"FocusGained",
		"InsertLeave",
		"CmdlineEnter",
		"CmdwinEnter",
	}, {
		group = group,
		callback = function()
			zenhan_off(opts)
		end,
	})
end

return M
