return {
	"gbprod/substitute.nvim",
	dependencies = {
		"y3owk1n/undo-glow.nvim",
	},
	opts = {
		highlight_substituted_text = {
			enabled = false,
		},
	},
	keys = {
		{
			"s",
			function()
				require("undo-glow").substitute_action(require("substitute").operator)
			end,
			mode = "n",
			desc = "Substitute with motion",
		},
		{
			"ss",
			function()
				require("undo-glow").substitute_action(require("substitute").line)
			end,
			mode = "n",
			desc = "Substitute line",
		},
		{
			"S",
			function()
				require("undo-glow").substitute_action(require("substitute").eol)
			end,
			mode = "n",
			desc = "Substitute to EOL",
		},
		{
			"s",
			function()
				require("undo-glow").substitute_action(require("substitute").visual)
			end,
			mode = "x",
			desc = "Substitute selection",
		},
	},
}
