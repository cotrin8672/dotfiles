return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	opts = {
		map_bs = false,
	},
	config = function(_, opts)
		local autopairs = require("nvim-autopairs")
		local cond = require("nvim-autopairs.conds")
		local Rule = require("nvim-autopairs.rule")

		autopairs.setup(opts)
		autopairs.add_rule(Rule("<", ">", {
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
		}):with_pair(cond.not_before_char("<", 1)):with_pair(cond.not_after_text(">")))
	end,
}
