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
		{ "erooke/blink-cmp-latex", ft = { "markdown", "tex", "plaintex", "latex" } },
	},
	event = { "BufReadPost", "BufNewFile" },
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
				show_with_menu = false,
			},
			menu = {
				winblend = float.blend,
				auto_show_delay_ms = 50,
			},
			documentation = {
				auto_show = false,
				auto_show_delay_ms = 300,
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
				default = function()
					local sources = { "snippets", "buffer", "path", "lsp" }
					if vim.bo.filetype == "lua" then
						table.insert(sources, "lazydev")
					elseif vim.bo.filetype == "java" then
						table.insert(sources, "mcdev")
					end
					if vim.g.copilot_enabled == true then
						table.insert(sources, "copilot")
					end
					return sources
				end,
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
					enabled = function()
						return vim.g.copilot_enabled == true
					end,
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
