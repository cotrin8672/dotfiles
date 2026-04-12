return {
	name = "dial.nvim",
	"monaqa/dial.nvim",
	keys = {
		{
			"<C-a>",
			function()
				require("dial.map").manipulate("increment", "normal")
			end,
			silent = true,
			remap = false,
			mode = "n",
			desc = "Increment value",
		},
		{
			"<C-a>",
			function()
				require("dial.map").manipulate("increment", "visual")
			end,
			silent = true,
			remap = false,
			mode = "x",
			desc = "Increment value",
		},
		{
			"<C-x>",
			function()
				require("dial.map").manipulate("decrement", "normal")
			end,
			silent = true,
			remap = false,
			mode = "n",
			desc = "Decrement value",
		},
		{
			"<C-x>",
			function()
				require("dial.map").manipulate("decrement", "visual")
			end,
			silent = true,
			remap = false,
			mode = "x",
			desc = "Decrement value",
		},
	},
	config = function()
		local augend = require("dial.augend")
		require("dial.config").augends:register_group({
			default = {
				augend.integer.alias.decimal,
				augend.integer.alias.hex,
				augend.date.alias["%Y/%m/%d"],
				augend.constant.alias.bool,
			},
		})
	end,
}
