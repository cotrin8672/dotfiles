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
		format_on_save = function(bufnr)
			-- matlab_ls formatting requires a live MATLAB connection and otherwise
			-- blocks every save while the server waits for MATLAB.
			if vim.bo[bufnr].filetype == "matlab" then
				return false
			end

			-- ktfmt starts a JVM for every invocation.  On Windows its cold
			-- start is commonly slower than Conform's default 1s timeout.
			local timeout_ms = vim.bo[bufnr].filetype == "kotlin" and 5000 or 500
			return {
				timeout_ms = timeout_ms,
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
