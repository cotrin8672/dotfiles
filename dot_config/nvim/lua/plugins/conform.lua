return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	opts = {
		formatters = {
			["google-java-format"] = { prepend_args = { "--aosp" } },
		},
		formatters_by_ft = {
			c = { "clang_format" },
			cpp = { "clang_format" },
			java = { "google-java-format" },
			lua = { "stylua" },
			nix = { "alejandra" },
			css = { "prettier" },
			html = { "prettier" },
			javascript = { "prettier" },
			javascriptreact = { "prettier" },
			json = { "prettier" },
			jsonc = { "prettier" },
			markdown = { "prettier" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			zsh = { "shfmt" },
			rust = { "rustfmt" },
			toml = { "taplo" },
			typescript = { "prettier" },
			typescriptreact = { "prettier" },
		},
		-- Java code actions contain positions that after-save formatting can invalidate.
		format_on_save = function(bufnr)
			if vim.bo[bufnr].filetype == "java" then
				return { timeout_ms = 2000, lsp_format = "never" }
			end
		end,
		format_after_save = function(bufnr)
			if vim.bo[bufnr].filetype == "java" then
				return
			end
			return {
				lsp_format = "fallback",
			}, require("config.lint").format_started(bufnr)
		end,
	},
	config = function(_, opts)
		require("conform").setup(opts)
	end,
}
