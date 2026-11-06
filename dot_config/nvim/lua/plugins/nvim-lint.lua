return {
	"mfussenegger/nvim-lint",
	event = "User LazyFile",
	config = function()
		local lint = require("lint")
		lint.linters.fatou = {
			cmd = "fatou",
			stdin = false,
			args = { "lint", "--output", "json" },
			stream = "stdout",
			ignore_exitcode = true,
			parser = function(output, bufnr)
				if output:match("^%s*$") then
					return {}
				end
				local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
				local newline_size = vim.bo[bufnr].fileformat == "dos" and 2 or 1
				local starts = { 0 }
				for i, line in ipairs(lines) do
					starts[i + 1] = starts[i] + #line + newline_size
				end
				local function position(offset)
					local row = 1
					while row < #lines and starts[row + 1] <= offset do
						row = row + 1
					end
					return row - 1, math.min(#lines[row], math.max(0, offset - starts[row]))
				end
				local diagnostics = {}
				for _, item in ipairs(vim.json.decode(output)) do
					local row, col = position(item.range.start)
					local end_row, end_col = position(item.range["end"])
					diagnostics[#diagnostics + 1] = {
						lnum = row,
						col = col,
						end_lnum = end_row,
						end_col = end_col,
						message = item.message.body,
						code = item.rule,
						severity = item.severity == "error" and vim.diagnostic.severity.ERROR
							or vim.diagnostic.severity.WARN,
						source = "fatou",
					}
				end
				return diagnostics
			end,
		}
		lint.linters.ktlint.args = {
			"--reporter=json",
			"--stdin",
			function()
				local name = vim.api.nvim_buf_get_name(0)
				return "--stdin-path=" .. (name ~= "" and name or "stdin.kt")
			end,
		}
		local clangtidy = lint.linters.clangtidy
		clangtidy.parser = require("lint.parser").from_pattern(
			"(.+):(%d+):(%d+): (%w+): ([^[]+) %[(.*)%]",
			{ "file", "lnum", "col", "severity", "message", "code" },
			{
				error = vim.diagnostic.severity.ERROR,
				warning = vim.diagnostic.severity.WARN,
				information = vim.diagnostic.severity.INFO,
				hint = vim.diagnostic.severity.HINT,
				note = vim.diagnostic.severity.HINT,
			},
			{ source = "clang-tidy" }
		)
		local matlab_include = require("config.matlab.toolchain").clang_include_flag()
		if matlab_include then
			clangtidy.args = { "--quiet", "--extra-arg=" .. matlab_include }
		end

		lint.linters_by_ft = {
			c = { "clangtidy" },
			cpp = { "clangtidy" },
			julia = { "fatou" },
			javascript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescript = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			markdown = { "markdownlint" },
			sh = { "shellcheck" },
			zsh = { "shellcheck" },
			-- Kotlin uses IntelliJ formatting; run ktlint explicitly when a project requires it.
		}

		local group = vim.api.nvim_create_augroup("nvim-lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
			group = group,
			pattern = "*",
			callback = function(event)
				local coordinator = require("config.lint")
				if event.event == "InsertLeave" then
					coordinator.insert_leave(event.buf)
				elseif not vim.b[event.buf].conform_applying_formatting then
					coordinator.after_save(event.buf)
				end
			end,
		})
	end,
}
