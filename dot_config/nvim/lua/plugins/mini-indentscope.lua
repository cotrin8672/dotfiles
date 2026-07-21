return {
	"nvim-mini/mini.indentscope",
	event = { "BufReadPost", "BufNewFile" },

	opts = function()
		local indentscope = require("mini.indentscope")

		return {
			draw = {
				delay = 0,
				animation = indentscope.gen_animation.none(),
				priority = 200,
			},
			symbol = "│",
		}
	end,

	config = function(_, opts)
		local indentscope = require("mini.indentscope")

		local function apply_hl()
			local function hl(name, key)
				local ok, value = pcall(vim.api.nvim_get_hl, 0, {
					name = name,
					link = true,
				})
				if ok and value and value[key] then
					return string.format("#%06x", value[key])
				end
			end

			local fg = hl("MiniStatuslineModeCommand", "bg") or hl("Aqua", "fg") or hl("DiagnosticInfo", "fg") or hl("Whitespace", "fg")

			if not fg then
				return
			end

			vim.api.nvim_set_hl(0, "MiniIndentscopeSymbol", {
				fg = fg,
				nocombine = true,
			})
			vim.api.nvim_set_hl(0, "MiniIndentscopeSymbolOff", {
				fg = fg,
				nocombine = true,
			})
		end

		local group = vim.api.nvim_create_augroup("MiniIndentscopeColors", { clear = true })

		apply_hl()

		vim.api.nvim_create_autocmd("ColorScheme", {
			group = group,
			callback = apply_hl,
		})

		indentscope.setup(opts)
	end,
}
