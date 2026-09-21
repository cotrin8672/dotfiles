local M = {}

local include_dir
local resolved = false

function M.include_dir()
	if resolved then
		return include_dir
	end
	resolved = true

	local root = vim.env.MATLAB_ROOT
	if not root or root == "" then
		local executable = vim.fn.exepath("matlab")
		if executable == "" then
			return nil
		end
		root = vim.fs.dirname(vim.fs.dirname(executable))
	end

	local candidate = vim.fs.joinpath(root, "extern", "include")
	if vim.uv.fs_stat(candidate) then
		include_dir = candidate
	end
	return include_dir
end

function M.clang_include_flag()
	local dir = M.include_dir()
	return dir and ("-I" .. dir) or nil
end

return M
