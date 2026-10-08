return {
	"stevearc/overseer.nvim",
	cmd = { "OverseerToggle", "OverseerRun", "OverseerRunCmd" },
	opts = {
		dap = true,
		component_aliases = {
			default_with_qf = {
				{ "on_output_quickfix", open = false, items_only = true },
				"default",
			},
			vscode_with_qf = {
				{ "on_output_quickfix", open = false, items_only = true },
				"default_vscode",
			},
		},
	},
}
