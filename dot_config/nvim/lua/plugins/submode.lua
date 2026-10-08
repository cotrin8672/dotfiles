return {
	"sirasagi62/nvim-submode",
	event = "VeryLazy",
	config = function()
		local sm = require("nvim-submode")
		sm.register_statusline(require("plugins.submode.shared").refresh_ui)

		require("plugins.submode.window")(sm)
		require("plugins.submode.debug")(sm)
	end,
}
