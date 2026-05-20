return {
	"neanias/everforest-nvim",
	lazy = false,
	priority = 1000,
	config = function()
		require("everforest").setup({
			background = "hard",
			italics = false,
			transparent_background_level = 2,
		})
		vim.cmd.colorscheme("everforest")

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
