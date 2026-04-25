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
				{ mode = "n", keys = "<C-w>" },
			},
			clues = {
				{ mode = "n", keys = "<Leader>a", desc = "+align" },
				{ mode = "n", keys = "<Leader>e", desc = "Oil float" },
				{ mode = "n", keys = "<Leader>O", desc = "Oil cwd" },
				{ mode = "n", keys = "<Leader>p", desc = "+pick" },
				{ mode = "n", keys = "<Leader>pb", desc = "Pick git branches" },
				{ mode = "n", keys = "<Leader>pd", desc = "Pick diagnostics" },
				{ mode = "n", keys = "<Leader>pf", desc = "Pick git files" },
				{ mode = "n", keys = "<Leader>pg", desc = "Live grep" },
				{ mode = "n", keys = "<Leader>pq", desc = "Pick quickfix" },
				{ mode = "n", keys = "<Leader>ps", desc = "Pick document symbols" },
				{ mode = "n", keys = "<Leader>pS", desc = "Pick workspace symbols" },
				{ mode = "n", keys = "<Leader>r", desc = "+rename" },
				{ mode = "n", keys = "<Leader>t", desc = "+trouble" },
				{ mode = "n", keys = "<Leader>tt", desc = "Trouble diagnostics" },
				{ mode = "n", keys = "<Leader>u", desc = "Undotree" },
				{ mode = "n", keys = "<Leader>x", desc = "Delete buffer" },
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
