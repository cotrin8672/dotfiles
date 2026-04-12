return {
	"sirasagi62/nvim-submode",
	event = "VeryLazy",
	config = function()
		local sm = require("nvim-submode")

		require("plugins.submode.window")(sm)
		require("plugins.submode.debug")(sm)
	end,
}
