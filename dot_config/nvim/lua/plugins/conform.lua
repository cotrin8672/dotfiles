return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	opts = {
		formatters_by_ft = {
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
		format_on_save = {
			timeout_ms = 500,
			lsp_format = "fallback",
		},
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
