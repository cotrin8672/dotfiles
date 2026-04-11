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
			accept = {
				auto_brackets = {
					kind_resolution = {
						blocked_filetypes = { "java", "kotlin" },
					},
					semantic_token_resolution = {
						blocked_filetypes = { "java", "kotlin" },
					},
				},
			},
			menu = {
				winblend = float.blend,
			},
			documentation = {
				auto_show = false,
				window = {
					winblend = float.blend,
				},
			},
		},
		sources = {
			default = {
				"lazydev",
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
			},
		},
	},
}
