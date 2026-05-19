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

local function get_hl_bg(name)
	local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
	if hl.bg ~= nil then
		return hl.bg
	end
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
		bg = get_hl_bg(bg_hl) or get_hl_bg("TabLineFill") or get_hl_bg("TabLine"),
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
		local theme = {
			fill = "TabLineFill",
			head = "TabLineSel",
			current_tab = "TabLineSel",
			tab = "TabLine",
			current = "TabLineSel",
			inactive = "TabLine",
			tail = "TabLine",
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
