return {
	"nvim-mini/mini.animate",
	event = "User LazyFile",
	opts = function()
		local animate = require("mini.animate")
		local timing = animate.gen_timing.linear({ duration = 70, unit = "total" })

		return {
			cursor = {
				enable = false,
			},
			scroll = {
				enable = true,
				timing = animate.gen_timing.linear({ duration = 40, unit = "total" }),
				subscroll = animate.gen_subscroll.equal({ max_output_steps = 4 }),
			},
			resize = {
				enable = true,
				timing = timing,
			},
			open = {
				enable = true,
				timing = timing,
			},
			close = {
				enable = true,
				timing = timing,
			},
		}
	end,
}
