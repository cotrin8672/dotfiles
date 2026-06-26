return {
	"LukasKorotaj/luasnip-markdown-snippets.nvim",
	lazy = true,
	init = function()
		vim.api.nvim_create_autocmd("InsertEnter", {
			group = vim.api.nvim_create_augroup("LazyLoadMarkdownSnippets", { clear = true }),
			callback = function(args)
				if vim.bo[args.buf].filetype == "markdown" then
					require("lazy").load({ plugins = { "luasnip-markdown-snippets.nvim" } })
					return true
				end
			end,
		})
	end,
	dependencies = { "L3MON4D3/LuaSnip" },
	opts = {},
}
