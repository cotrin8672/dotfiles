return {
	"cotrin8672/sub-action.nvim",
	dependencies = { "sirasagi62/nvim-submode" },
	opts = {
		preview = function(action, context)
			if action.edit or context.client.name ~= "kotlin_lsp" then
				return
			end
			local command = type(action.command) == "table" and action.command or action
			if command.command == "applyModCommand" then
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
