local float = require("shared.float")

return {
	"Saghen/blink.cmp",
	version = "1.*",
	dependencies = {
		{
			"Saghen/blink.lib",
			lazy = true,
		},
		"L3MON4D3/LuaSnip",
		"erooke/blink-cmp-latex",
		"mcdev-nvim",
	},
	event = "InsertEnter",
	opts = {
		keymap = {
			preset = "enter",
		},
		appearance = {
			nerd_font_variant = "mono",
		},
		snippets = {
			preset = "luasnip",
		},
		completion = {
			list = {
				selection = {
					preselect = true,
					auto_insert = false,
				},
			},
			accept = {
				auto_brackets = {
					enabled = true,
				},
			},
			ghost_text = {
				enabled = true,
				show_with_menu = true,
			},
			menu = {
				winblend = float.blend,
			},
			documentation = {
				auto_show = true,
				window = {
					winblend = float.blend,
					direction_priority = {
						menu_north = { "e", "w", "n" },
						menu_south = { "e", "w", "n" },
					},
				},
			},
			keyword = {
				range = "full",
			},
		},
		sources = {
			default = {
				"snippets",
				"lazydev",
				"copilot",
				"buffer",
				"path",
				"lsp",
				"mcdev",
			},
			providers = {
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					score_offset = 100,
				},
				copilot = {
					name = "copilot",
					module = "blink-cmp-copilot",
					score_offset = 100,
					async = true,
				},
				latex = {
					name = "latex",
					module = "blink-cmp-latex",
					enabled = function()
						local ft = vim.bo.filetype
						return ft == "tex" or ft == "plaintex" or ft == "latex" or ft == "markdown"
					end,
					opts = {
						insert_command = true,
					},
				},
				mcdev = {
					name = "mcdev",
					module = "mcdev.blink",
				},
			},
		},
	},
}
