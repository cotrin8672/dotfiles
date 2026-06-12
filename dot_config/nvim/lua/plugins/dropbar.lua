return {
	"Bekaboo/dropbar.nvim",
	event = "BufEnter",
	config = function()
		local sources = require("dropbar.sources")
		local utils = require("dropbar.utils")
		local dropbar_symbol_t = require("dropbar.bar").dropbar_symbol_t
		local symbol_new = dropbar_symbol_t.new

		function dropbar_symbol_t:new(opts)
			local name = opts and opts.name
			if type(name) ~= "string" then
				opts.name = type(name) == "table"
						and (name[1] or name.label or name.value or name.name or vim.inspect(name))
					or (name == nil and "" or tostring(name))
			end
			return symbol_new(self, opts)
		end

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
