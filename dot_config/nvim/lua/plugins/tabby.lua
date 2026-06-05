local M = {}

local function listed_normal_buffers()
	local bufs = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.bo[bufnr].buflisted and vim.bo[bufnr].buftype == "" then
			bufs[#bufs + 1] = bufnr
		end
	end
	return bufs
end

local function cycle_buffer(step)
	if require("config.matlab.command_window").is_command_window() then
		return
	end

	local bufs = listed_normal_buffers()
	if #bufs == 0 then
		return
	end

	local current = vim.api.nvim_get_current_buf()
	local current_index = 1
	for index, bufnr in ipairs(bufs) do
		if bufnr == current then
			current_index = index
			break
		end
	end

	local next_index = ((current_index - 1 + step) % #bufs) + 1
	vim.api.nvim_set_current_buf(bufs[next_index])
end

function M.next_buffer()
	cycle_buffer(1)
end

function M.previous_buffer()
	cycle_buffer(-1)
end

local function update_tabby_visibility()
	vim.o.showtabline = 2
end

local function get_hl_attr(name, attr)
	local hl = vim.api.nvim_get_hl(0, { name = name, link = true })
	local value = hl[attr]
	assert(value, string.format("missing highlight attribute: %s.%s", name, attr))
	return value
end

local function apply_tabby_highlights()
	local normal_fg = get_hl_attr("Normal", "fg")
	local muted_fg = get_hl_attr("StatusLineNC", "fg")
	local active_bg = get_hl_attr("DiagnosticHint", "fg")
	local active_fg = get_hl_attr("Search", "fg")
	local inactive_bg = get_hl_attr("CursorLine", "bg")
	local fill_bg = get_hl_attr("PmenuSel", "bg")

	vim.api.nvim_set_hl(0, "TabbyFill", {
		fg = muted_fg,
		bg = fill_bg,
	})
	vim.api.nvim_set_hl(0, "TabbyHead", {
		fg = active_bg,
		bg = fill_bg,
		bold = true,
	})
	vim.api.nvim_set_hl(0, "TabbyActive", {
		fg = active_fg,
		bg = active_bg,
		bold = true,
	})
	vim.api.nvim_set_hl(0, "TabbyInactive", {
		fg = normal_fg,
		bg = inactive_bg,
	})
	vim.api.nvim_set_hl(0, "TabbyTail", {
		fg = get_hl_attr("DiagnosticOk", "fg"),
		bg = fill_bg,
		bold = true,
	})
end

local function buffer_file_icon(bufnr, bg_hl)
	local path = vim.api.nvim_buf_get_name(bufnr)
	local category = vim.fn.isdirectory(path) == 1 and "directory" or "file"
	local ok, icon, icon_hl = pcall(require("mini.icons").get, category, path)
	if not ok then
		return ""
	end

	local icon_hl_data = vim.api.nvim_get_hl(0, { name = icon_hl, link = false })
	local hl = "TabbyIcon" .. icon_hl .. bg_hl
	vim.api.nvim_set_hl(0, hl, {
		fg = icon_hl_data.fg,
		bg = get_hl_attr(bg_hl, "bg"),
	})

	return { icon, hl = hl }
end

return vim.tbl_extend("force", M, {
	"nanozuki/tabby.nvim",
	lazy = false,
	dependencies = {
		"mini.icons",
		"mini.bufremove",
	},
	config = function()
		apply_tabby_highlights()

		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("TabbyContrastColors", { clear = true }),
			callback = apply_tabby_highlights,
		})

		local theme = {
			fill = "TabbyFill",
			head = "TabbyHead",
			current_tab = "TabbyActive",
			tab = "TabbyInactive",
			current = "TabbyActive",
			inactive = "TabbyInactive",
			tail = "TabbyTail",
		}

		require("tabby").setup({
			line = function(line)
				return {
					{
						{ "  ", hl = theme.head },
						line.sep("", theme.head, theme.fill),
					},
					line.tabs().foreach(function(tab)
						local hl = tab.is_current() and theme.current_tab or theme.tab
						return {
							line.sep("", hl, theme.fill),
							tab.in_jump_mode() and tab.jump_key() or tab.number(),
							tab.is_current() and " ●" or " ○",
							line.sep("", hl, theme.fill),
							hl = hl,
							margin = "",
						}
					end),
					line.spacer(),
					line.bufs()
						.filter(function(buf)
							return vim.bo[buf.id].buflisted and buf.type() == ""
						end)
						.foreach(function(buf)
							local hl = buf.is_current() and theme.current or theme.inactive
							local modified = buf.is_changed() and "● " or ""
							return {
								line.sep("", hl, theme.fill),
								buffer_file_icon(buf.id, hl),
								" ",
								{ modified, hl = hl },
								buf.name(),
								line.sep("", hl, theme.fill),
								hl = hl,
								margin = "",
							}
						end),
					{
						line.sep("", theme.tail, theme.fill),
						{ "  ", hl = theme.tail },
					},
					hl = theme.fill,
				}
			end,
			option = {
				buf_name = {
					mode = "unique",
				},
			},
		})

		vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FileType" }, {
			callback = update_tabby_visibility,
		})
		vim.api.nvim_create_autocmd("User", {
			pattern = "MiniStarterOpened",
			callback = update_tabby_visibility,
		})
		vim.schedule(update_tabby_visibility)

		local key_opts = { noremap = true, silent = true }
		vim.keymap.set("n", "<Tab>", M.next_buffer, key_opts)
		vim.keymap.set("n", "<S-Tab>", M.previous_buffer, key_opts)
		vim.keymap.set("n", "<leader>x", function()
			vim.cmd("silent update")
			require("mini.bufremove").delete(0, false)
		end, key_opts)
	end,
})
