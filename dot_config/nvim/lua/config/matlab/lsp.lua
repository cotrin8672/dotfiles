local M = {}

local configured_capabilities = nil

local function matlab_settings(connection_timing, index_workspace)
	local matlab_exe = vim.fn.exepath("matlab")
	local matlab_install_path = matlab_exe ~= "" and vim.fn.fnamemodify(matlab_exe, ":h:h") or ""

	return {
		MATLAB = {
			indexWorkspace = index_workspace,
			installPath = matlab_install_path,
			matlabConnectionTiming = connection_timing,
			telemetry = true,
		},
	}
end

function M.setup(capabilities)
	configured_capabilities = capabilities

	vim.lsp.config("matlab_ls", {
		capabilities = capabilities,
		settings = matlab_settings("onStart", true),
	})
end

function M.execution_root(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	return vim.fs.root(bufnr, ".git") or vim.fn.getcwd()
end

function M.exec_config(bufnr, handlers, on_exit)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	return {
		name = "matlab_ls_exec",
		cmd = { "matlab-language-server", "--stdio" },
		root_dir = M.execution_root(bufnr),
		capabilities = configured_capabilities or vim.lsp.protocol.make_client_capabilities(),
		settings = matlab_settings("onStart", false),
		handlers = handlers,
		on_exit = on_exit,
	}
end

return M
