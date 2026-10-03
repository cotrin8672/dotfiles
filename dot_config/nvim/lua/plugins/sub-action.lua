return {
	"cotrin8672/sub-action.nvim",
	dependencies = { "sirasagi62/nvim-submode" },
	opts = {
		preview = function(action)
			if not action.edit then
				return require("shared.intellij_mod_command").preview(action)
			end
		end,
	},
	keys = {
		{
			"gra",
			function()
				require("sub_action").open()
			end,
			desc = "LSP Code Action",
		},
	},
}
