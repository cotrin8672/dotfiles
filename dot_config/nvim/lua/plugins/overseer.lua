return {
	"stevearc/overseer.nvim",
	cmd = { "OverseerToggle", "OverseerRun", "OverseerRunCmd" },
	opts = {
		dap = true,
	},
	templates = {
		"builtin",
		"user",
	},
	components = {
		{ "unique" },
	},
	component_aliases = {
		default_with_qf = {
			{
				"on_output_quickfix",
				open = false,
				items_only = true,
			},
		},
		vscode_with_qf = {
			{
				"on_output_quickfix",
				open = false,
				items_only = true,
			},
			"default_vscode",
		},
	},
}
