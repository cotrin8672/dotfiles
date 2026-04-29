local float = require("shared.float")

return {
	"Saghen/blink.cmp",
	build = "cargo build --release",
	event = "InsertEnter",
	opts = {
		keymap = {
			preset = "enter",
		},
		appearance = {
			nerd_font_variant = "mono",
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
				},
			},
		},
		sources = {
			default = {
				"lazydev",
				"copilot",
				"buffer",
				"path",
				"lsp",
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
			},
		},
	},
}
