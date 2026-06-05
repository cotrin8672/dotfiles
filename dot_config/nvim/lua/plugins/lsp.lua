return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason-org/mason-lspconfig.nvim",
	},
	config = function()
		local capabilities = vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), {
			textDocument = {
				completion = {
					completionItem = {
						snippetSupport = true,
						commitCharactersSupport = false,
						documentationFormat = { "markdown", "plaintext" },
						deprecatedSupport = true,
						preselectSupport = false,
						tagSupport = { valueSet = { 1 } },
						insertReplaceSupport = true,
						resolveSupport = {
							properties = {
								"documentation",
								"detail",
								"additionalTextEdits",
								"command",
								"data",
							},
						},
						insertTextModeSupport = {
							valueSet = { 1 },
						},
						labelDetailsSupport = true,
					},
					completionList = {
						itemDefaults = {
							"commitCharacters",
							"editRange",
							"insertTextFormat",
							"insertTextMode",
							"data",
						},
					},
					contextSupport = true,
					insertTextMode = 1,
				},
			},
		})
		local diagnostic_icons = require("shared.diagnostic_icons")

		vim.diagnostic.config({
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = diagnostic_icons.error_icon,
					[vim.diagnostic.severity.WARN] = diagnostic_icons.warn_icon,
					[vim.diagnostic.severity.HINT] = diagnostic_icons.hint_icon,
					[vim.diagnostic.severity.INFO] = diagnostic_icons.info_icon,
				},
			},
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			callback = function(args)
				local bufnr = args.buf
				local map = function(lhs, rhs)
					vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true })
				end

				map("gd", vim.lsp.buf.definition)
				map("gr", vim.lsp.buf.references)
				map("gi", vim.lsp.buf.implementation)
				map("K", vim.lsp.buf.hover)
				vim.keymap.set("n", "<leader>rn", function()
					return ":IncRename " .. vim.fn.expand("<cword>")
				end, { buffer = bufnr, silent = true, expr = true })
				map("[d", function()
					vim.diagnostic.jump({ count = -1, float = true })
				end)
				map("]d", function()
					vim.diagnostic.jump({ count = 1, float = true })
				end)
			end,
		})

		vim.lsp.config("lua_ls", {
			capabilities = capabilities,
			settings = {
				Lua = {
					diagnostics = {
						globals = {
							"vim",
						},
					},
				},
			},
		})

		vim.lsp.config("nixd", {
			capabilities = capabilities,
		})

		vim.lsp.config("bashls", {
			capabilities = capabilities,
		})

		vim.lsp.config("jsonls", {
			capabilities = capabilities,
			settings = {
				json = {
					schemas = require("schemastore").json.schemas(),
					validate = { enable = true },
				},
			},
		})

		vim.lsp.config("html", {
			capabilities = capabilities,
		})

		vim.lsp.config("cssls", {
			capabilities = capabilities,
		})

		vim.lsp.config("ts_ls", {
			capabilities = capabilities,
		})

		vim.lsp.config("rust_analyzer", {
			capabilities = capabilities,
		})

		vim.lsp.config("taplo", {
			capabilities = capabilities,
		})

		vim.lsp.config("marksman", {
			capabilities = capabilities,
		})

		vim.lsp.config("texlab", {
			capabilities = capabilities,
		})

		require("config.matlab.lsp").setup(capabilities)
	end,
}
