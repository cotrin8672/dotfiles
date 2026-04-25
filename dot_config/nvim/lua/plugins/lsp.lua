return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		"mason-org/mason-lspconfig.nvim",
	},
	config = function()
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		local diagnostic_icons = require("shared.diagnostic_icons")

		pcall(function()
			capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
		end)

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

		local matlab_exe = vim.fn.exepath("matlab")
		local matlab_install_path = matlab_exe ~= "" and vim.fn.fnamemodify(matlab_exe, ":h:h") or ""

		vim.lsp.config("matlab_ls", {
			capabilities = capabilities,
			settings = {
				MATLAB = {
					indexWorkspace = false,
					installPath = matlab_install_path,
					matlabConnectionTiming = "onStart",
					telemetry = true,
				},
			},
		})
	end,
}
