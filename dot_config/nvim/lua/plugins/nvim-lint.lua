return {
	"mfussenegger/nvim-lint",
	event = "User LazyFile",
	config = function()
		local lint = require("lint")
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
			javascript = { "eslint_d" },
			javascriptreact = { "eslint_d" },
			typescript = { "eslint_d" },
			typescriptreact = { "eslint_d" },
			markdown = { "markdownlint" },
			sh = { "shellcheck" },
			zsh = { "shellcheck" },
			rust = { "clippy" },
			java = { "checklint" },
			kotlin = { "ktlint" },
		}

		local group = vim.api.nvim_create_augroup("nvim-lint", { clear = true })
		vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
			group = group,
			pattern = "*",
			callback = function()
				lint.try_lint()
			end,
		})
	end,
}
