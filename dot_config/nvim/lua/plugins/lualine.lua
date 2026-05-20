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

		require("lualine").setup({
			options = {
				theme = "auto",
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
		})

		local ok_cursor, cursor_mode = pcall(require, "ui.cursor_mode")
		if ok_cursor then
			cursor_mode.refresh()
		end
	end,
}
