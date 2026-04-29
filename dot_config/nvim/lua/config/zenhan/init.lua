local M = {}

local function zenhan_off(opts)
	if vim.fn.executable(opts.command) == 0 then
		vim.notify_once("zenhan.exe not found", vim.log.levels.ERROR)
		return
	end

	pcall(vim.system, { opts.command, opts.off_arg }, {
		stdout = false,
		stderr = false,
	}, function() end)
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
