local M = {}
local pending, scheduled, formatting = {}, {}, {}

local function run(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
		return
	end
	local lint = package.loaded.lint
	if lint then
		vim.api.nvim_buf_call(bufnr, function()
			lint.try_lint()
		end)
	end
end

function M.after_save(bufnr)
	pending[bufnr] = true
	if scheduled[bufnr] then
		return
	end
	scheduled[bufnr] = true
	vim.schedule(function()
		scheduled[bufnr] = nil
		if pending[bufnr] and not formatting[bufnr] then
			pending[bufnr] = nil
			run(bufnr)
		end
	end)
end

function M.format_started(bufnr)
	local token = {}
	formatting[bufnr] = token
	return function()
		if formatting[bufnr] == token then
			formatting[bufnr] = nil
			M.after_save(bufnr)
		end
	end
end

function M.insert_leave(bufnr)
	-- ktlint starts a JVM; run it after saving instead of on every mode change.
	if vim.bo[bufnr].filetype == "kotlin" then
		return
	end
	if formatting[bufnr] then
		M.after_save(bufnr)
	else
		run(bufnr)
	end
end

return M
