local float = require("shared.float")

return {
	"Saghen/blink.cmp",
	version = false,
	build = function()
		package.loaded["blink.cmp"] = nil
		require("blink.cmp").build():pwait()
	end,
	dependencies = {
		{
			"Saghen/blink.lib",
			lazy = true,
		},
		"L3MON4D3/LuaSnip",
		"erooke/blink-cmp-latex",
		"mcdev-nvim",
	},
	event = "VeryLazy",
	opts = {
		keymap = {
			preset = "enter",
		},
		appearance = {
			nerd_font_variant = "mono",
		},
		snippets = {
			preset = "luasnip",
			jump = function(direction)
				local ls = require("luasnip")
				if not require("blink.cmp").is_visible() and not ls.locally_jumpable(1) and ls.expandable() then
					return ls.expand_or_jump()
				end
				if not ls.jumpable(direction) then
					return false
				end
				if vim.bo.filetype == "matlab" and vim.fn.mode() == "i" then
					-- LuaSnip changes rows by API; close the current insert undo
					-- block first so undo restores both text and cursor history.
					vim.cmd("let &l:undolevels = &l:undolevels")
				end
				return ls.jump(direction)
			end,
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
					enabled = false,
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
			default = function()
				return require("mcdev.blink").route_sources({
					"snippets",
					"lazydev",
					"copilot",
					"path",
					"lsp",
					"mcdev",
				})()
			end,
			providers = {
				snippets = {
					should_show_items = function(ctx)
						if vim.bo[ctx.bufnr].filetype ~= "matlab" then
							return true
						end
						local state = require("config.matlab.syntax").context(ctx.bufnr, ctx.pos.row)
						local before = ctx.line:sub(1, ctx.pos.col)
						-- The MATLAB snippets create statements/blocks, so an
						-- argument or expression must use expression completions.
						return not state.logical
							and not state.in_block_comment
							and before:match("^%s*[%a_][%w_]*$") ~= nil
					end,
					min_keyword_length = function(ctx)
						return vim.bo[ctx.bufnr].filetype == "matlab" and 1 or 0
					end,
					score_offset = function(ctx)
						return vim.bo[ctx.bufnr].filetype == "matlab" and 5 or -1
					end,
				},
				lsp = {
					transform_items = function(ctx, items)
						items = require("config.rust.completion")(ctx, items)
						if not ctx.line:match('^%s*#%s*include%s+[<"]') then
							return items
						end
						for _, item in ipairs(items) do
							local edit = item.textEdit
							if edit and edit.insert and edit.replace then
								edit.replace = edit.insert
							end
						end
						return items
					end,
				},
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					score_offset = 100,
					enabled = function()
						return vim.bo.filetype == "lua"
					end,
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
					score_offset = 100,
				},
			},
		},
	},
}
