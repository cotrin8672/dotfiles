local M = {}

function M.get_client(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()

	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	for _, client in ipairs(clients) do
		if client.name == "matlab_ls" then
			return client
		end
	end

	return nil
end

return M
