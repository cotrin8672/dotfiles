return {
	"Bekaboo/dropbar.nvim",
	event = "BufEnter",
	config = function()
		local sources = require("dropbar.sources")
		local utils = require("dropbar.utils")

		require("dropbar").setup({
			bar = {
				enable = false,
				sources = function(buf, _)
					if vim.bo[buf].filetype == "markdown" then
						return {
							sources.markdown,
						}
					end

					return {
						utils.source.fallback({
							sources.lsp,
							sources.treesitter,
						}),
					}
				end,
			},
			icons = {
				ui = {
					bar = {
						separator = " ",
					},
				},
			},
		})
	end,
}
