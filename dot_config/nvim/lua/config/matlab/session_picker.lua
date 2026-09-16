local M = {}

local function items()
	local result = {}
	for _, session in ipairs(require("config.matlab.core").list_sessions()) do
		local root = session.root_dir and vim.fn.fnamemodify(session.root_dir, ":t") or ""
		result[#result + 1] = vim.tbl_extend("force", session, {
			text = table.concat({ tostring(session.id), session.state, root }, " "),
			session_id = session.id,
			root = root,
		})
	end
	return result
end

local function format(item)
	local icon = item.state == "connected" and "●" or (item.state == "connecting" and "◐" or "○")
	local icon_hl = item.state == "connected" and "DiagnosticOk"
		or (item.state == "connecting" and "DiagnosticWarn" or "Comment")
	local current = item.current and "› " or "  "
	local root = item.root ~= "" and ("  " .. item.root) or ""
	return {
		{ current, item.current and "Special" or "Normal" },
		{ tostring(item.index) .. " ", item.current and "Special" or "Normal" },
		{ icon, icon_hl },
		{ root, "Comment" },
	}
end

local function preview(ctx)
	local bufnr = require("config.matlab.command_window").buffer_for_session(ctx.item.session_id)
	ctx.preview:set_title(("MATLAB Session %d"):format(ctx.item.index))
	ctx.preview:set_buf(bufnr)
	local line = vim.api.nvim_buf_line_count(bufnr)
	vim.api.nvim_win_set_cursor(ctx.win, { line, 0 })
end

local function select_session(picker, item)
	local ok, err = require("config.matlab.core").select_session(item.session_id)
	if ok == false then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end
	picker:close()
end

local function enter_preview(picker, item)
	local bufnr = require("config.matlab.command_window").buffer_for_session(item.session_id)
	picker.preview:set_title(("MATLAB Session %d"):format(item.index))
	picker.preview:set_buf(bufnr)
	picker:focus("preview", { show = true })
	vim.schedule(function()
		if not picker.preview.win:valid() then
			return
		end
		local preview_bufnr = vim.api.nvim_win_get_buf(picker.preview.win.win)
		local line = vim.api.nvim_buf_line_count(preview_bufnr)
		vim.api.nvim_win_set_cursor(picker.preview.win.win, { line, 0 })
		if vim.fn.prompt_getprompt(preview_bufnr) ~= "" then
			vim.cmd("startinsert")
		end
	end)
end

local function picker_options()
	return {
		source = "matlab_sessions",
		title = "MATLAB Sessions",
		finder = items,
		format = format,
		preview = preview,
		confirm = select_session,
		actions = {
			enter_preview = enter_preview,
		},
		win = {
			input = { keys = { ["<C-l>"] = { "enter_preview", mode = { "n", "i" } } } },
			list = { keys = { ["<C-l>"] = "enter_preview" } },
		},
	}
end

function M.open()
	if #require("config.matlab.core").list_sessions() == 0 then
		vim.notify("No MATLAB sessions", vim.log.levels.WARN)
		return nil
	end

	return Snacks.picker(picker_options())
end

M._picker_options = picker_options

return M
