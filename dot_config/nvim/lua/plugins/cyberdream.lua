return {
	"scottmckendry/cyberdream.nvim",
	lazy = false,
	priority = 1000,
	opts = {
		transparent = true,
		italic_comments = false,
		overrides = function(colors)
			return {
				NormalFloat = { fg = colors.fg, bg = colors.bg_alt },
				FloatBorder = { fg = colors.grey, bg = colors.bg_alt },
				FloatTitle = { fg = colors.cyan, bg = colors.bg_alt },
				Pmenu = { fg = colors.fg, bg = colors.bg_alt },
				PmenuBorder = { fg = colors.grey, bg = colors.bg_alt },
				PmenuSel = { fg = colors.fg, bg = colors.bg_highlight },
				Visual = { bg = "#625062" },
				VisualNOS = { bg = "#625062" },
				WinSeparator = { fg = colors.grey, bg = colors.bg },
				VertSplit = { fg = colors.grey, bg = colors.bg },
			}
		end,
	},
	config = function(_, opts)
		require("cyberdream").setup(opts)
		vim.cmd.colorscheme("cyberdream")

		local function hl(name, key)
			local ok, value = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
			if ok and value and value[key] then
				return string.format("#%06x", value[key])
			end
		end

		local dim = hl("StatusLineNC", "fg") or hl("LineNr", "fg")
		local subtle = hl("Comment", "fg") or hl("StatusLine", "fg") or hl("Whitespace", "fg")

		vim.api.nvim_set_hl(0, "LineNr", { fg = dim })
		vim.api.nvim_set_hl(0, "LineNrAbove", { fg = dim })
		vim.api.nvim_set_hl(0, "LineNrBelow", { fg = dim })
		vim.api.nvim_set_hl(0, "CursorLineNr", { fg = dim })
		vim.api.nvim_set_hl(0, "LspInlayHint", { fg = dim })
		vim.api.nvim_set_hl(0, "Whitespace", { fg = subtle })
	end,
}
