return {
	"rcarriga/nvim-notify",
	event = "VeryLazy",
	opts = {
		top_down = true,
	},
	config = function(_, opts)
		local notify = require("notify")
		notify.setup(opts)
		vim.notify = notify
	end,
}
