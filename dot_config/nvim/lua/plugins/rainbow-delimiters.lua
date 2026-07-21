return {
	"HiPhish/rainbow-delimiters.nvim",
	event = { "BufReadPost", "BufNewFile" },
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		local rainbow_delimiters = require("rainbow-delimiters")
		local performance = require("config.performance")
		vim.g.rainbow_delimiters = {
			strategy = {
				[""] = function(bufnr)
					if performance.disable_decorations(bufnr) then
						return nil
					end
					return rainbow_delimiters.strategy["global"]
				end,
				vim = rainbow_delimiters.strategy["local"],
			},
			query = {
				[""] = "rainbow-delimiters",
				lua = "rainbow-blocks",
			},
			highlight = {
				"RainbowDelimiterRed",
				"RainbowDelimiterYellow",
				"RainbowDelimiterBlue",
				"RainbowDelimiterOrange",
				"RainbowDelimiterGreen",
				"RainbowDelimiterViolet",
				"RainbowDelimiterCyan",
			},
		}
	end,
}
