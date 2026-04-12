return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	config = function()
		local autopairs = require("nvim-autopairs")
		local cond = require("nvim-autopairs.conds")
		local Rule = require("nvim-autopairs.rule")

		autopairs.setup({})
		autopairs.add_rule(
			Rule("<", ">", {
				"-astro",
				"-eruby",
				"-heex",
				"-html",
				"-htmldjango",
				"-javascriptreact",
				"-php",
				"-svelte",
				"-typescriptreact",
				"-vue",
				"-xml",
			})
				:with_pair(cond.not_before_char("<"))
				:with_pair(cond.not_after_text(">"))
		)
	end,
}
