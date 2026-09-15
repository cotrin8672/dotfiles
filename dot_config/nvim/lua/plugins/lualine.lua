return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = {
		"mini.icons",
	},
	config = function()
		local diagnostic_icons = require("ui.diagnostic_icons")
		local mode = require("lualine.utils.mode")
		local repo_name_cache = {}
		local diagnostic_cache = {}
		local lsp_client_cache = {}

		local function hl_color(name, attr)
			local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
			if not ok or not hl or not hl[attr] then
				return nil
			end
			return string.format("#%06x", hl[attr])
		end

		local function first_color(attr, names)
			for _, name in ipairs(names) do
				local color = hl_color(name, attr)
				if color then
					return color
				end
			end
		end

		local function apply_transparent_winbar()
			local fg = first_color("fg", { "WinBar", "Normal", "StatusLine" })
			local fg_nc = first_color("fg", { "WinBarNC", "Comment", "Normal" }) or fg

			vim.api.nvim_set_hl(0, "WinBar", { fg = fg, bg = "NONE" })
			vim.api.nvim_set_hl(0, "WinBarNC", { fg = fg_nc, bg = "NONE" })
		end

		local function transparent_winbar_color()
			return {
				fg = first_color("fg", { "WinBar", "Normal", "StatusLine" }),
				bg = "NONE",
			}
		end

		local function tabline_like_theme()
			local background = first_color("bg", { "Normal", "StatusLine", "Pmenu", "CursorLine" })
			local surface = first_color("bg", { "StatusLineNC", "PmenuSel", "CursorLine", "TabLine" }) or background
			local foreground = first_color("fg", { "Normal", "StatusLine" })
			local accent = first_color("fg", { "DiagnosticInfo", "Identifier", "Function" })
			local insert = first_color("fg", { "DiagnosticOk", "String" }) or accent
			local visual = first_color("fg", { "Statement", "DiagnosticHint" }) or accent
			local replace = first_color("fg", { "DiagnosticWarn", "WarningMsg" }) or accent
			local command = first_color("fg", { "DiagnosticHint", "Special" }) or accent

			return {
				normal = {
					a = { fg = background, bg = accent, gui = "bold" },
					b = { fg = accent, bg = surface },
					c = { fg = foreground, bg = background },
				},
				insert = {
					a = { fg = background, bg = insert, gui = "bold" },
					b = { fg = insert, bg = surface },
					c = { fg = foreground, bg = background },
				},
				visual = {
					a = { fg = background, bg = visual, gui = "bold" },
					b = { fg = visual, bg = surface },
					c = { fg = foreground, bg = background },
				},
				replace = {
					a = { fg = background, bg = replace, gui = "bold" },
					b = { fg = replace, bg = surface },
					c = { fg = foreground, bg = background },
				},
				command = {
					a = { fg = background, bg = command, gui = "bold" },
					b = { fg = command, bg = surface },
					c = { fg = foreground, bg = background },
				},
				inactive = {
					a = { fg = foreground, bg = background },
					b = { fg = foreground, bg = background },
					c = { fg = foreground, bg = background },
				},
			}
		end

		local function submode_label()
			local sm = package.loaded["nvim-submode"]
			local name = sm and sm.get_submode_name()
			if name and name ~= "" then
				return name
			end
			return mode.get_mode()
		end

		local function repo_name()
			local path = vim.api.nvim_buf_get_name(0)
			if path == "" then
				path = vim.loop.cwd()
			else
				path = vim.fs.dirname(path)
			end

			local cached = repo_name_cache[path]
			if cached ~= nil then
				return cached
			end

			local git_dir = vim.fs.find(".git", { path = path, upward = true })[1]
			if not git_dir then
				repo_name_cache[path] = ""
				return ""
			end

			local name = vim.fs.basename(vim.fs.dirname(git_dir))
			repo_name_cache[path] = name
			return name
		end

		local function diagnostics_summary()
			local bufnr = vim.api.nvim_get_current_buf()
			local cached = diagnostic_cache[bufnr]
			if cached ~= nil then
				if cached == false then
					return nil
				end
				return cached.total, cached.severity
			end

			local diagnostics = vim.diagnostic.get(bufnr)
			local total = #diagnostics
			if total == 0 then
				diagnostic_cache[bufnr] = false
				return nil
			end

			local has_error = false
			local has_warn = false
			local has_hint = false

			for _, diagnostic in ipairs(diagnostics) do
				if diagnostic.severity == vim.diagnostic.severity.ERROR then
					has_error = true
					break
				elseif diagnostic.severity == vim.diagnostic.severity.WARN then
					has_warn = true
				elseif diagnostic.severity == vim.diagnostic.severity.HINT then
					has_hint = true
				end
			end

			if has_error then
				diagnostic_cache[bufnr] = { total = total, severity = vim.diagnostic.severity.ERROR }
				return total, vim.diagnostic.severity.ERROR
			end
			if has_warn then
				diagnostic_cache[bufnr] = { total = total, severity = vim.diagnostic.severity.WARN }
				return total, vim.diagnostic.severity.WARN
			end
			if has_hint then
				diagnostic_cache[bufnr] = { total = total, severity = vim.diagnostic.severity.HINT }
				return total, vim.diagnostic.severity.HINT
			end
			diagnostic_cache[bufnr] = { total = total, severity = vim.diagnostic.severity.INFO }
			return total, vim.diagnostic.severity.INFO
		end

		local function lsp_client_names()
			local bufnr = vim.api.nvim_get_current_buf()
			local cached = lsp_client_cache[bufnr]
			if cached ~= nil then
				return cached
			end

			local clients = vim.lsp.get_clients({ bufnr = bufnr })
			if #clients == 0 then
				lsp_client_cache[bufnr] = ""
				return ""
			end

			local names = {}
			for _, client in ipairs(clients) do
				names[#names + 1] = client.name
			end

			table.sort(names)
			local value = table.concat(names, ", ")
			lsp_client_cache[bufnr] = value
			return value
		end

		local function lsp_diagnostics()
			local lsp_status = vim.lsp.status()
			local total, severity = diagnostics_summary()

			if lsp_status == "" then
				lsp_status = lsp_client_names()
			end

			if lsp_status == "" then
				return ""
			end

			if not total then
				return table.concat({
					"",
					" ",
					lsp_status,
					" ",
					"",
					" ",
				})
			end

			local icon = diagnostic_icons.info_icon
			if severity == vim.diagnostic.severity.ERROR then
				icon = diagnostic_icons.error_icon
			elseif severity == vim.diagnostic.severity.WARN then
				icon = diagnostic_icons.warn_icon
			elseif severity == vim.diagnostic.severity.HINT then
				icon = diagnostic_icons.hint_icon
			end

			return table.concat({
				"",
				" ",
				lsp_status,
				" ",
				icon,
				tostring(total),
			})
		end

		local function dropbar_location()
			if not package.loaded["dropbar"] or not _G.dropbar then
				return ""
			end

			local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
			if not vim.api.nvim_win_is_valid(win) then
				return ""
			end

			local buf = vim.api.nvim_win_get_buf(win)
			local bars = _G.dropbar.bars
			local buf_bars = bars and bars[buf]
			local bar = buf_bars and buf_bars[win]
			if not bar then
				return ""
			end

			return bar()
		end

		local function winbar_filename()
			local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
			if not vim.api.nvim_win_is_valid(win) then
				return ""
			end

			local buf = vim.api.nvim_win_get_buf(win)
			local path = vim.api.nvim_buf_get_name(buf)
			local name = vim.fn.fnamemodify(path, ":t")
			if name == "" then
				return ""
			end

			local ok, icons = pcall(require, "mini.icons")
			if not ok then
				return name
			end

			local icon, icon_hl = icons.get("file", path)
			return "%#" .. icon_hl .. "#" .. icon .. "%* " .. name
		end

		local function winbar_line()
			local location = dropbar_location()
			local filename = winbar_filename()
			if location == "" then
				return "%=" .. filename
			end
			if filename == "" then
				return location
			end
			return location .. "%=" .. filename
		end

		local winbar = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = {
				{
					winbar_line,
					color = transparent_winbar_color,
				},
			},
			lualine_x = {},
			lualine_y = {},
			lualine_z = {},
		}

		apply_transparent_winbar()
		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("transparent_winbar", { clear = true }),
			callback = apply_transparent_winbar,
		})

		local cache_group = vim.api.nvim_create_augroup("LualineCachedComponents", { clear = true })
		vim.api.nvim_create_autocmd("DiagnosticChanged", {
			group = cache_group,
			callback = function(args)
				if args.buf then
					diagnostic_cache[args.buf] = nil
				else
					diagnostic_cache = {}
				end
			end,
		})
		vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
			group = cache_group,
			callback = function(args)
				lsp_client_cache[args.buf] = nil
			end,
		})
		vim.api.nvim_create_autocmd("BufWipeout", {
			group = cache_group,
			callback = function(args)
				diagnostic_cache[args.buf] = nil
				lsp_client_cache[args.buf] = nil
			end,
		})
		vim.api.nvim_create_autocmd("DirChanged", {
			group = cache_group,
			callback = function()
				repo_name_cache = {}
			end,
		})

		require("lualine").setup({
			options = {
				theme = tabline_like_theme(),
				section_separators = { left = "", right = "" },
				component_separators = { left = "╲", right = "╲" },
				disabled_filetypes = {
					statusline = { "ministarter" },
					winbar = { "ministarter" },
				},
			},
			sections = {
				lualine_a = {
					{
						submode_label,
						separator = { left = "", right = "" },
						padding = { left = 1, right = 1 },
					},
				},
				lualine_b = {
					{
						repo_name,
						icon = "󰉋",
						separator = { left = "", right = "" },
					},
					{
						"branch",
						icon = "",
					},
				},
				lualine_c = {},
				lualine_x = {
					{
						lsp_diagnostics,
						padding = { left = 1, right = 1 },
					},
				},
				lualine_y = {
					{
						"filetype",
					},
				},
				lualine_z = {
					{
						"location",
						separator = { left = "", right = "" },
						padding = { left = 1, right = 1 },
					},
				},
			},
			winbar = winbar,
			inactive_winbar = winbar,
		})

		local ok_cursor, cursor_mode = pcall(require, "ui.cursor_mode")
		if ok_cursor then
			cursor_mode.refresh()
		end
	end,
}
