return {
	"nvim-mini/mini.clue",
	event = "VeryLazy",
	opts = function()
		local clue = require("mini.clue")

		return {
			triggers = {
				{ mode = "n", keys = "<Leader>" },
				{ mode = "x", keys = "<Leader>" },
				{ mode = "n", keys = "g" },
				{ mode = "x", keys = "g" },
				{ mode = "n", keys = "[" },
				{ mode = "n", keys = "]" },
				{ mode = "n", keys = "z" },
				{ mode = "x", keys = "z" },
			},
			clues = {
				{ mode = "n", keys = "<Leader>f", desc = "+find" },
				{ mode = "n", keys = "<Leader>g", desc = "+git" },
				{ mode = "n", keys = "<Leader>p", desc = "+pick" },
				clue.gen_clues.builtin_completion(),
				clue.gen_clues.g(),
				clue.gen_clues.marks(),
				clue.gen_clues.registers(),
				clue.gen_clues.windows(),
				clue.gen_clues.z(),
			},
			window = {
				delay = 300,
			},
		}
	end,
}
