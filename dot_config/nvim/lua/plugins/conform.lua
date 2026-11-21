local fatou_command

return {
	"stevearc/conform.nvim",
	event = { "BufWritePre" },
	opts = {
		formatters = {
			["google-java-format"] = { prepend_args = { "--aosp" } },
			fatou = {
				command = function()
					if not fatou_command then
						fatou_command = "fatou"
						if vim.fn.executable("mise") == 1 then
							local result = vim.system({ "mise", "which", "fatou" }, { text = true }):wait(5000)
							local path = vim.trim(result.stdout or "")
							if result.code == 0 and vim.fn.executable(path) == 1 then
								fatou_command = path
							end
						end
					end
					return fatou_command
				end,
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
				lsp_format = vim.bo[bufnr].filetype == "julia" and "never" or "fallback",
			},
				require("config.lint").format_started(bufnr)
		end,
	},
	config = function(_, opts)
		require("conform").setup(opts)
	end,
}
