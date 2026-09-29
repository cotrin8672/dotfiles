local M = {}
local icon_cache = {}
local tabline_cache
local tabline_columns
local tabline_scrolloff
local buffer_scroll = 0

local function scrolloff()
	return math.max(0, math.floor(vim.g.tabby_scrolloff or 8))
end

local function invalidate_tabline()
	tabline_cache = nil
end

local function render_tabline()
	if tabline_columns ~= vim.o.columns or tabline_scrolloff ~= scrolloff() then
		invalidate_tabline()
		tabline_columns = vim.o.columns
		tabline_scrolloff = scrolloff()
	end
	if require("tabby.feature.tab_jumper").is_start then
		return require("tabby.tabline").render()
	end

	tabline_cache = tabline_cache or require("tabby.tabline").render()
	return tabline_cache
end

local function render_node(node)
	local builder = require("tabby.module.builder"):new()
	builder:render_element(node, {})
	local rendered =
		vim.api.nvim_eval_statusline(builder:build(), { use_tabline = true, maxwidth = 0, highlights = true })
	rendered.width = vim.fn.strdisplaywidth(rendered.str)
	return rendered
end

local function clip_node(node, rendered, left, right)
	local clipped = { hl = node.hl }
	local column = 0
	for index, highlight in ipairs(rendered.highlights) do
		local finish = rendered.highlights[index + 1] and rendered.highlights[index + 1].start or #rendered.str
		local text = {}
		for _, char in ipairs(vim.fn.split(rendered.str:sub(highlight.start + 1, finish), "\\zs")) do
			local next_column = column + vim.fn.strdisplaywidth(char, column)
			local overlap = math.min(right, next_column) - math.max(left, column)
			if overlap > 0 then
				text[#text + 1] = column >= left and next_column <= right and char or string.rep(" ", overlap)
			end
			column = next_column
			if column >= right then
				break
			end
		end
		if #text > 0 then
			clipped[#clipped + 1] = {
				(table.concat(text):gsub("%%", "%%%%")),
				hl = highlight.groups[#highlight.groups],
				click = node.click,
			}
		end
		if column >= right then
			break
		end
	end
	return clipped
end

local function scroll_buffers(nodes, width)
	local rendered, total, current_left, current_right = {}, 0, nil, nil
	for index, node in ipairs(nodes) do
		rendered[index] = render_node(node)
		if node.click[2] == vim.api.nvim_get_current_buf() then
			current_left, current_right = total, total + rendered[index].width
		end
		total = total + rendered[index].width
	end
	if current_left then
		local current_width = current_right - current_left
		local margin = math.min(scrolloff(), math.max(0, math.floor((width - current_width) / 2)))
		if current_width >= width then
			buffer_scroll = current_left
		else
			buffer_scroll = math.min(buffer_scroll, current_left - margin)
			buffer_scroll = math.max(buffer_scroll, current_right + margin - width)
		end
	end
	buffer_scroll = math.max(0, math.min(buffer_scroll, total - width))
	local visible, position = {}, 0
	for index, node in ipairs(nodes) do
		local item = rendered[index]
		local left = math.max(0, buffer_scroll - position)
		local right = math.min(item.width, buffer_scroll + width - position)
		if left < right then
			visible[#visible + 1] = left == 0 and right == item.width and node or clip_node(node, item, left, right)
		end
		position = position + item.width
	end
	visible[#visible + 1] = string.rep(" ", math.max(0, width - (total - buffer_scroll)))
	return visible
end

local function is_jdtls_class_buffer(bufnr)
	if vim.bo[bufnr].buftype ~= "nofile" or vim.bo[bufnr].filetype ~= "java" then
		return false
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	return vim.startswith(name, "jdt://") or name:lower():match("%.class$") ~= nil
end

local function is_tabby_buffer(bufnr)
	return vim.bo[bufnr].buflisted and (vim.bo[bufnr].buftype == "" or is_jdtls_class_buffer(bufnr))
end

local function listed_tabby_buffers()
	local bufs = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if is_tabby_buffer(bufnr) then
			bufs[#bufs + 1] = bufnr
		end
	end
	return bufs
end

local function cycle_buffer(step)
	if require("config.matlab.command_window").is_command_window() then
		return
	end

	local bufs = listed_tabby_buffers()
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

local function get_hl_attr(names, attr)
	for _, name in ipairs(names) do
		local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
		if ok and hl[attr] then
			return hl[attr]
		end
	end
end

local function apply_tabby_highlights()
	local normal_fg = get_hl_attr({ "Normal", "StatusLine" }, "fg")
	local muted_fg = get_hl_attr({ "StatusLineNC", "Comment", "Normal" }, "fg")
	local active_bg = get_hl_attr({ "DiagnosticHint", "Identifier", "Normal" }, "fg")
	local active_fg = get_hl_attr({ "Search", "Normal", "StatusLine" }, "fg")
	local inactive_bg = get_hl_attr({ "CursorLine", "StatusLine", "Pmenu", "Normal" }, "bg")
	local fill_bg = get_hl_attr({ "PmenuSel", "StatusLineNC", "Pmenu", "CursorLine", "Normal" }, "bg")

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
		fg = get_hl_attr({ "DiagnosticOk", "String", "DiagnosticHint", "Normal" }, "fg"),
		bg = fill_bg,
		bold = true,
	})
end

local function buffer_file_icon(bufnr, bg_hl)
	local path = vim.api.nvim_buf_get_name(bufnr)
	local cached = icon_cache[bufnr]
	if not cached or cached.path ~= path then
		cached = {
			path = path,
			category = vim.fn.isdirectory(path) == 1 and "directory" or "file",
			values = {},
		}
		icon_cache[bufnr] = cached
	end
	if cached.values[bg_hl] then
		return cached.values[bg_hl]
	end
	local ok, icon, icon_hl = pcall(require("mini.icons").get, cached.category, path)
	if not ok then
		return ""
	end

	local icon_hl_data = vim.api.nvim_get_hl(0, { name = icon_hl, link = false })
	local hl = "TabbyIcon" .. icon_hl .. bg_hl
	vim.api.nvim_set_hl(0, hl, {
		fg = icon_hl_data.fg,
		bg = get_hl_attr({ bg_hl, "Normal" }, "bg"),
	})

	local value = { icon, hl = hl }
	cached.values[bg_hl] = value
	return value
end

return vim.tbl_extend("force", M, {
	"nanozuki/tabby.nvim",
	event = "VeryLazy",
	dependencies = {
		"mini.icons",
	},
	config = function()
		apply_tabby_highlights()

		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("TabbyContrastColors", { clear = true }),
			callback = function()
				icon_cache = {}
				apply_tabby_highlights()
			end,
		})
		vim.api.nvim_create_autocmd({ "BufFilePost", "BufWipeout" }, {
			callback = function(args)
				icon_cache[args.buf] = nil
			end,
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
				local head = {
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
					hl = theme.fill,
				}
				local tail = {
					line.sep("", theme.tail, theme.fill),
					{ "  ", hl = theme.tail },
					hl = theme.fill,
				}
				local width = vim.o.columns - render_node(head).width - render_node(tail).width
				if width < 10 then
					head, tail, width = {}, {}, vim.o.columns
				end
				local buffers = line.bufs()
					.filter(function(buf)
						return is_tabby_buffer(buf.id)
					end)
					.foreach(function(buf)
						local hl = buf.is_current() and theme.current or theme.inactive
						local modified = buf.is_changed() and "● " or ""
						return {
							line.sep("", hl, theme.fill),
							buffer_file_icon(buf.id, hl),
							" ",
							{ modified, hl = hl },
							(buf.name():gsub("%%", "%%%%")),
							line.sep("", hl, theme.fill),
							hl = hl,
							margin = "",
						}
					end)
				return {
					head,
					scroll_buffers(buffers, width),
					tail,
					hl = theme.fill,
				}
			end,
			option = {
				buf_name = {
					mode = "unique",
				},
			},
		})
		_G.TabbyRenderCached = render_tabline
		vim.o.tabline = "%!v:lua.TabbyRenderCached()"

		local cache_group = vim.api.nvim_create_augroup("TabbyRenderCache", { clear = true })
		vim.api.nvim_create_autocmd({
			"BufAdd",
			"BufDelete",
			"BufEnter",
			"BufFilePost",
			"BufModifiedSet",
			"BufWipeout",
			"ColorScheme",
			"FileType",
			"SessionLoadPost",
			"TabClosed",
			"TabEnter",
			"TabNew",
		}, {
			group = cache_group,
			callback = invalidate_tabline,
		})
		vim.api.nvim_create_autocmd("OptionSet", {
			group = cache_group,
			pattern = "buflisted",
			callback = invalidate_tabline,
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
	end,
})
