local mode_accent = require("ui.mode_accent")

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = {
		"mini.icons",
	},
	config = function()
		local diagnostic_icons = require("ui.diagnostic_icons")
		local sm = require("nvim-submode")
		local mode = require("lualine.utils.mode")
		local function hl(name, key)
			local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
			if ok and value and value[key] then
				return string.format("#%06x", value[key])
			end
		end

		local colors = {
			bg0 = hl("MiniStatuslineModeNormal", "fg") or hl("TabLineSel", "fg") or hl("Normal", "bg"),
			bg3 = hl("TabLine", "bg") or hl("StatusLine", "bg"),
			bg5 = hl("Conceal", "fg") or hl("StatusLineNC", "bg") or hl("StatusLine", "bg"),
			fg = hl("Normal", "fg") or hl("StatusLine", "fg"),
			grey1 = hl("Comment", "fg") or hl("StatusLine", "fg"),
			green = hl("Directory", "fg") or hl("MiniStatuslineModeNormal", "bg"),
			red = hl("DiagnosticError", "fg") or hl("Error", "fg"),
			orange = hl("MiniStatuslineModeReplace", "bg") or hl("Label", "fg") or hl("DiagnosticWarn", "fg"),
			aqua = hl("MiniStatuslineModeCommand", "bg") or hl("Aqua", "fg") or hl("DiagnosticInfo", "fg"),
			purple = hl("DiagnosticHint", "fg") or hl("MiniStatuslineModeOther", "bg"),
		}

		local theme = {
			normal = {
				a = { bg = colors.green, fg = colors.bg0, gui = "bold" },
				b = { bg = colors.bg3, fg = colors.fg },
				c = { bg = colors.bg5, fg = colors.fg },
			},
			insert = {
				a = { bg = colors.fg, fg = colors.bg0, gui = "bold" },
				b = { bg = colors.bg3, fg = colors.fg },
				c = { bg = colors.bg5, fg = colors.fg },
			},
			visual = {
				a = { bg = colors.red, fg = colors.bg0, gui = "bold" },
				b = { bg = colors.bg3, fg = colors.fg },
				c = { bg = colors.bg5, fg = colors.fg },
			},
			replace = {
				a = { bg = colors.orange, fg = colors.bg0, gui = "bold" },
				b = { bg = colors.bg3, fg = colors.fg },
				c = { bg = colors.bg5, fg = colors.fg },
			},
			command = {
				a = { bg = colors.aqua, fg = colors.bg0, gui = "bold" },
				b = { bg = colors.bg3, fg = colors.fg },
				c = { bg = colors.bg5, fg = colors.fg },
			},
			terminal = {
				a = { bg = colors.purple, fg = colors.bg0, gui = "bold" },
				b = { bg = colors.bg3, fg = colors.fg },
				c = { bg = colors.bg5, fg = colors.fg },
			},
			inactive = {
				a = { bg = colors.bg5, fg = colors.grey1, gui = "bold" },
				b = { bg = colors.bg5, fg = colors.grey1 },
				c = { bg = colors.bg5, fg = colors.grey1 },
			},
		}

		mode_accent.set_mode_colors({
			normal = theme.normal.a.bg,
			insert = theme.insert.a.bg,
			visual = theme.visual.a.bg,
			replace = theme.replace.a.bg,
			command = theme.command.a.bg,
			terminal = theme.terminal.a.bg,
		})

		vim.api.nvim_set_hl(0, "LualineLspDiag", { fg = colors.fg, bg = colors.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagError", { fg = colors.red, bg = colors.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagWarn", { fg = colors.orange, bg = colors.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagHint", { fg = colors.aqua, bg = colors.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagInfo", { fg = colors.green, bg = colors.bg5 })

		local function submode_label()
			local name = sm.get_submode_name()
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

			local git_dir = vim.fs.find(".git", { path = path, upward = true })[1]
			if not git_dir then
				return ""
			end

			return vim.fs.basename(vim.fs.dirname(git_dir))
		end

		local function submode_bg()
			local color = mode_accent.get_accent_color()
			return color and { bg = color } or nil
		end

		local function diagnostics_summary()
			local diagnostics = vim.diagnostic.get(0)
			local total = #diagnostics
			if total == 0 then
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
				return total, vim.diagnostic.severity.ERROR
			end
			if has_warn then
				return total, vim.diagnostic.severity.WARN
			end
			if has_hint then
				return total, vim.diagnostic.severity.HINT
			end
			return total, vim.diagnostic.severity.INFO
		end

		local function lsp_client_names()
			local clients = vim.lsp.get_clients({ bufnr = 0 })
			if #clients == 0 then
				return ""
			end

			local names = {}
			for _, client in ipairs(clients) do
				names[#names + 1] = client.name
			end

			table.sort(names)
			return table.concat(names, ", ")
		end

		local function lsp_diagnostics()
			local base_hl = "%#LualineLspDiag#"
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
					base_hl,
					"",
					" ",
					lsp_status,
					" ",
					"%#LualineLspDiagInfo#",
					"",
					" ",
					base_hl,
				})
			end

			local icon = diagnostic_icons.info_icon
			local icon_hl = "%#LualineLspDiagInfo#"
			if severity == vim.diagnostic.severity.ERROR then
				icon = diagnostic_icons.error_icon
				icon_hl = "%#LualineLspDiagError#"
			elseif severity == vim.diagnostic.severity.WARN then
				icon = diagnostic_icons.warn_icon
				icon_hl = "%#LualineLspDiagWarn#"
			elseif severity == vim.diagnostic.severity.HINT then
				icon = diagnostic_icons.hint_icon
				icon_hl = "%#LualineLspDiagHint#"
			end

			return table.concat({
				base_hl,
				"",
				" ",
				lsp_status,
				" ",
				icon_hl,
				icon,
				base_hl,
				tostring(total),
			})
		end

		require("lualine").setup({
			options = {
				theme = theme,
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
						color = submode_bg,
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
						color = { bg = colors.bg5, fg = colors.fg },
					},
				},
				lualine_c = {},
				lualine_x = {
					{
						lsp_diagnostics,
						color = { bg = colors.bg5, fg = colors.fg },
						padding = { left = 1, right = 1 },
					},
				},
				lualine_y = {
					{
						"filetype",
						color = { bg = colors.bg3, fg = colors.fg },
					},
				},
				lualine_z = {
					{
						"location",
						color = submode_bg,
						separator = { left = "", right = "" },
						padding = { left = 1, right = 1 },
					},
				},
			},
		})

		local ok_cursor, cursor_mode = pcall(require, "ui.cursor_mode")
		if ok_cursor then
			cursor_mode.refresh()
		end
	end,
}
