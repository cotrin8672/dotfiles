-- nvim --headless --clean -i NONE -n -l tests/nvim_julia_fatou.lua
local root = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(root)
for _, plugin in ipairs({ "conform.nvim", "nvim-lint" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
local conform = require("conform")
conform.setup(require("plugins.conform").opts)
require("plugins.nvim-lint").config()
local lint = require("lint")
local path = vim.fn.tempname() .. ".jl"
local ok, err = pcall(function()
	vim.cmd("edit " .. vim.fn.fnameescape(path))
	vim.bo.filetype = "julia"
	local buf = vim.api.nvim_get_current_buf()
	assert(conform.get_formatter_info("fatou", buf).available, "Fatou executable unavailable")
	assert(conform.list_formatters(buf)[1].name == "fatou", "Julia formatter must be Fatou")
	assert(lint.linters_by_ft.julia[1] == "fatou", "Julia linter must be Fatou")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "x=1+2" })
	vim.cmd("write")
	assert(
		vim.wait(20000, function()
			return vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1] == "x = 1 + 2"
				and not vim.bo[buf].modified
				and vim.fn.readfile(path)[1] == "x = 1 + 2"
		end, 20),
		"Save must asynchronously format and update the file"
	)

	local namespace = lint.get_namespace("fatou")
	for _, fileformat in ipairs({ "unix", "dos" }) do
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "α = 1", "function f(", "end" })
		vim.bo.fileformat = fileformat
		vim.cmd("noautocmd write!")
		vim.diagnostic.reset(namespace, buf)
		lint.try_lint("fatou")
		assert(
			vim.wait(20000, function()
				return #vim.diagnostic.get(buf, { namespace = namespace }) > 0
			end, 20),
			"Fatou parse diagnostic missing for " .. fileformat
		)
		local diagnostic = vim.diagnostic.get(buf, { namespace = namespace })[1]
		assert(diagnostic.source == "fatou" and diagnostic.code == "parse-error")
		assert(diagnostic.lnum == 1 and diagnostic.col == 10, vim.inspect(diagnostic))
	end

	-- A parser byte range after a UTF-8 identifier must stay a byte column.
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "α + value" })
	local diagnostics = lint.linters.fatou.parser(
		vim.json.encode({
			{
				rule = "sample",
				severity = "warning",
				range = { start = 5, ["end"] = 10 },
				message = { body = "sample warning" },
			},
		}),
		buf
	)
	assert(diagnostics[1].col == 5 and diagnostics[1].end_col == 10)
	assert(diagnostics[1].severity == vim.diagnostic.severity.WARN)
end)
vim.cmd("silent! bwipeout!")
vim.fn.delete(path)
assert(ok, err)
print("JULIA_FATOU_FORMAT_LINT_OK")
