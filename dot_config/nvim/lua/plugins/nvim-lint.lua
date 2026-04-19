return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
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
