local M = {}

M.decorations_limit = 100 * 1024
M.treesitter_limit = 1024 * 1024

function M.file_size(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return 0
	end
	local stat = vim.uv.fs_stat(name)
	return stat and stat.size or 0
end

function M.disable_decorations(bufnr)
	return M.file_size(bufnr) > M.decorations_limit or vim.api.nvim_buf_line_count(bufnr) > 5000
end

function M.disable_treesitter(bufnr)
	return M.file_size(bufnr) > M.treesitter_limit or vim.api.nvim_buf_line_count(bufnr) > 20000
end

function M.setup()
	local group = vim.api.nvim_create_augroup("PerformanceLargeBuffers", { clear = true })
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = group,
		callback = function(args)
			if M.disable_decorations(args.buf) then
				vim.b[args.buf].miniindentscope_disable = true
				vim.b[args.buf].minihipatterns_disable = true
			end
		end,
	})
end

return M
