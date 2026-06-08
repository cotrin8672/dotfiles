return {
	"y3owk1n/undo-glow.nvim",
	event = "VeryLazy",
	opts = function()
		local fallback = {}
		local function hl(name, key)
			local ok, value = pcall(vim.api.nvim_get_hl, 0, {
				name = name,
				link = true,
			})
			if ok and value and value[key] then
				return string.format("#%06x", value[key])
			end
		end
		fallback.bg = hl("Normal", "bg") or hl("MiniStatuslineModeNormal", "fg") or hl("TabLineSel", "fg")
		fallback.fg = hl("Normal", "fg") or hl("StatusLine", "fg")

		return {
			fallback_for_transparency = fallback,
			animation = {
				enabled = true,
				duration = 300,
				animation_type = "fade",
				window_scoped = true,
			},
			highlights = {
				undo = {
					hl_color = { bg = "DiffDelete" },
				},
				redo = {
					hl_color = { bg = "DiffAdd" },
				},
				paste = {
					hl_color = { bg = "IncSearch" },
				},
				search = {
					hl_color = { bg = "CurSearch" },
				},
				comment = {
					hl_color = { bg = "CursorLine" },
				},
			},
		}
	end,
	keys = {
		{
			"u",
			function()
				require("undo-glow").undo()
			end,
			mode = "n",
			desc = "Undo with highlights",
			noremap = true,
			silent = true,
		},
		{
			"<C-r>",
			function()
				require("undo-glow").redo()
			end,
			mode = "n",
			desc = "Redo with highlights",
			noremap = true,
			silent = true,
		},
	},
	init = function()
		vim.api.nvim_create_autocmd("TextYankPost", {
			desc = "Highlight yanks",
			callback = function()
				require("undo-glow").yank()
			end,
		})

		vim.api.nvim_create_autocmd("CmdlineLeave", {
			desc = "Highlight search cmdline result",
			callback = function()
				require("undo-glow").search_cmd()
			end,
		})
	end,
}
