return {
	"cordx56/rustowl",
	version = "*",
	lazy = false,
	opts = {
		client = {
			cmd = { "mise", "exec", "--", "rustowl" },
			cmd_env = { MATLABROOT = vim.env.MATLABROOT or "C:/Program Files/MATLAB/R2024a" },
		},
	},
}
