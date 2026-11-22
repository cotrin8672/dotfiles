return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	opts = {
		formatters = {
			["google-java-format"] = { prepend_args = { "--aosp" } },
			fatou = {
				command = "fatou",
				args = { "format", "--safe", "-" },
				stdin = true,
				cwd = function(_, ctx)
					return ctx.dirname
				end,
			},
		},
		formatters_by_ft = {
			c = { "clang_format" },
			cpp = { "clang_format" },
			java = { "google-java-format" },
			julia = { "fatou", lsp_format = "never" },
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
		-- Julia formats before saving to avoid a second write on network shares.
		format_on_save = function(bufnr)
			local ft = vim.bo[bufnr].filetype
			if ft == "java" or ft == "julia" then
				return { timeout_ms = 2000, lsp_format = "never" }
			end
		end,
		format_after_save = function(bufnr)
			local ft = vim.bo[bufnr].filetype
			if ft == "java" or ft == "julia" then
				return
			end
			return { lsp_format = "fallback" }, require("config.lint").format_started(bufnr)
		end,
	},
	config = function(_, opts)
		require("conform").setup(opts)
	end,
}
