return {
	"LukasKorotaj/luasnip-markdown-snippets.nvim",
	lazy = true,
	init = function()
		local function load_if_markdown()
			if vim.bo.filetype == "markdown" then
				require("lazy").load({ plugins = { "luasnip-markdown-snippets.nvim" } })
				return true
			end
		end

		local group = vim.api.nvim_create_augroup("LazyLoadMarkdownSnippets", { clear = true })
		vim.api.nvim_create_autocmd("User", {
			group = group,
			pattern = "VeryLazy",
			once = true,
			callback = load_if_markdown,
		})
		vim.api.nvim_create_autocmd("InsertEnter", {
			group = group,
			callback = load_if_markdown,
		})
	end,
	dependencies = { "L3MON4D3/LuaSnip" },
	opts = {},
}
