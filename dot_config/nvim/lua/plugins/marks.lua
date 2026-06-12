return {
	"chentoast/marks.nvim",
	event = "VeryLazy",
	config = function()
		local utils = require("marks.utils")
		local add_sign = utils.add_sign
		local mark_signs = {
			a = "󰯬",
			b = "󰯯",
			c = "󰯲",
			d = "󰯵",
			e = "󰯸",
			f = "󰯻",
			g = "󰯾",
			h = "󰰁",
			i = "󰰄",
			j = "󰰇",
			k = "󰰊",
			l = "󰰍",
			m = "󰰐",
			n = "󰰓",
			o = "󰰖",
			p = "󰰙",
			q = "󰰜",
			r = "󰰟",
			s = "󰰢",
			t = "󰰥",
			u = "󰰨",
			v = "󰰫",
			w = "󰰮",
			x = "󰰱",
			y = "󰰴",
			z = "󰰷",
		}

		utils.add_sign = function(bufnr, text, line, id, group, priority)
			return add_sign(bufnr, mark_signs[text] or text, line, id, group, priority)
		end

		require("marks").setup({
			default_mappings = true,
			cyclic = true,
		})
	end,
}
