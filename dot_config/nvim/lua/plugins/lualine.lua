local mode_accent = require("ui.mode_accent")

return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = {
		"mini.icons",
	},
	config = function()
		local everforest = require("everforest")
		local colours = require("everforest.colours")
		local diagnostic_icons = require("ui.diagnostic_icons")
		local sm = require("nvim-submode")
		local mode = require("lualine.utils.mode")
		local palette = colours.generate_palette(everforest.config, vim.o.background)

		local theme = {
			normal = {
				a = { bg = palette.green, fg = palette.bg0, gui = "bold" },
				b = { bg = palette.bg3, fg = palette.fg },
				c = { bg = palette.bg5, fg = palette.fg },
			},
			insert = {
				a = { bg = palette.fg, fg = palette.bg0, gui = "bold" },
				b = { bg = palette.bg3, fg = palette.fg },
				c = { bg = palette.bg5, fg = palette.fg },
			},
			visual = {
				a = { bg = palette.red, fg = palette.bg0, gui = "bold" },
				b = { bg = palette.bg3, fg = palette.fg },
				c = { bg = palette.bg5, fg = palette.fg },
			},
			replace = {
				a = { bg = palette.orange, fg = palette.bg0, gui = "bold" },
				b = { bg = palette.bg3, fg = palette.fg },
				c = { bg = palette.bg5, fg = palette.fg },
			},
			command = {
				a = { bg = palette.aqua, fg = palette.bg0, gui = "bold" },
				b = { bg = palette.bg3, fg = palette.fg },
				c = { bg = palette.bg5, fg = palette.fg },
			},
			terminal = {
				a = { bg = palette.purple, fg = palette.bg0, gui = "bold" },
				b = { bg = palette.bg3, fg = palette.fg },
				c = { bg = palette.bg5, fg = palette.fg },
			},
			inactive = {
				a = { bg = palette.bg5, fg = palette.grey1, gui = "bold" },
				b = { bg = palette.bg5, fg = palette.grey1 },
				c = { bg = palette.bg5, fg = palette.grey1 },
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

		vim.api.nvim_set_hl(0, "LualineLspDiag", { fg = palette.fg, bg = palette.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagError", { fg = palette.red, bg = palette.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagWarn", { fg = palette.orange, bg = palette.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagHint", { fg = palette.aqua, bg = palette.bg5 })
		vim.api.nvim_set_hl(0, "LualineLspDiagInfo", { fg = palette.green, bg = palette.bg5 })

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
						color = { bg = palette.bg5, fg = palette.fg },
					},
				},
				lualine_c = {},
				lualine_x = {
					{
						lsp_diagnostics,
						color = { bg = palette.bg5, fg = palette.fg },
						padding = { left = 1, right = 1 },
					},
				},
				lualine_y = {
					{
						"filetype",
						color = { bg = palette.bg3, fg = palette.fg },
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
