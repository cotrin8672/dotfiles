return {
	"rachartier/tiny-cmdline.nvim",
	event = "UIEnter",
	opts = function()
		return {
			on_reposition = require("tiny-cmdline").adapters.blink,
		}
	end,
}
