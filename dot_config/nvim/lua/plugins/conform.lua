return {
	"stevearc/conform.nvim",
	event = { "BufWritePost" },
	opts = {
		formatters_by_ft = {
			c = { "clang_format" },
			cpp = { "clang_format" },
			java = { "google-java-format" },
			kotlin = { "ktfmt" },
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
		format_after_save = function()
			return {
				lsp_format = "fallback",
			}
		end,
		formatters = {
			ktfmt = {
				stdin = false,
				args = { "$FILENAME" },
			},
		},
	},
	config = function(_, opts)
		require("conform").setup(opts)
	end,
}
