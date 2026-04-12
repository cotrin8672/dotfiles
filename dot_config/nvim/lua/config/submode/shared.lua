local M = {}

function M.refresh_ui()
	vim.schedule(function()
		local ok, lualine = pcall(require, "lualine")
		if ok then
			lualine.refresh()
		end

		local ok_cursor, cursor_mode = pcall(require, "ui.cursor_mode")
		if ok_cursor then
			cursor_mode.refresh()
		end
	end)
end

return M
