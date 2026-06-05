local M = {}

function M.setup(capabilities)
	local matlab_exe = vim.fn.exepath("matlab")
	local matlab_install_path = matlab_exe ~= "" and vim.fn.fnamemodify(matlab_exe, ":h:h") or ""

	vim.lsp.config("matlab_ls", {
		capabilities = capabilities,
		settings = {
			MATLAB = {
				indexWorkspace = false,
				installPath = matlab_install_path,
				matlabConnectionTiming = "onStart",
				telemetry = true,
			},
		},
	})
end

return M
