return {
	"L3MON4D3/LuaSnip",
	lazy = true,
	build = "make install_jsregexp",
	opts = {
		enable_autosnippets = true,
		history = true,
		update_events = "TextChanged,TextChangedI",
		delete_check_events = "TextChanged",
	},
	config = function(_, opts)
		local ls = require("luasnip")
		ls.setup(opts)

		require("luasnip.loaders.from_lua").lazy_load({
			paths = {
				vim.fn.stdpath("config") .. "/lua/snippets",
			},
		})
	end,
}
