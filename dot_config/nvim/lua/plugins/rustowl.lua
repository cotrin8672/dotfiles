return {
	"cordx56/rustowl",
	version = "*",
	lazy = false,
	opts = {
		auto_enable = true,
		client = {
			cmd = { "mise", "exec", "--", "rustowl" },
			cmd_env = { MATLABROOT = vim.env.MATLABROOT or "C:/Program Files/MATLAB/R2024a" },
		},
	},
}
