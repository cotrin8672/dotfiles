return {
	"nvim-mini/mini.animate",
	event = "User LazyFile",
	opts = function()
		local animate = require("mini.animate")
		local timing = animate.gen_timing.linear({ duration = 70, unit = "total" })

		return {
			cursor = {
				enable = true,
				timing = timing,
				path = animate.gen_path.line({
					predicate = function(destination)
						return destination[1] ~= 0 or destination[2] ~= 0
					end,
				}),
			},
			scroll = {
				enable = true,
				timing = timing,
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
