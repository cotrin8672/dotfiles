return {
	"neovim/nvim-lspconfig",
	ft = require("config.lsp_filetypes"),
	config = function()
		local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
		local path_sep = vim.fn.has("win32") == 1 and ";" or ":"
		if not vim.env.PATH:find(vim.pesc(mason_bin), 1, false) then
			vim.env.PATH = mason_bin .. path_sep .. vim.env.PATH
		end

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
			float = { source = "always" },
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
				local client = vim.lsp.get_client_by_id(args.data.client_id)
				if client and client.name == "rust_analyzer" then
					vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
				end
				local map = function(lhs, rhs)
					vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true })
				end

				map("gd", function()
					if vim.bo[bufnr].filetype == "java" then
						require("kross").definition()
					else
						vim.lsp.buf.definition()
					end
				end)
				map("gr", function()
					if vim.bo[bufnr].filetype == "java" then
						local kross = require("kross")
						if kross.references then
							return kross.references()
						end
					end
					vim.lsp.buf.references()
				end)
				map("gi", vim.lsp.buf.implementation)
				if vim.bo[bufnr].filetype ~= "matlab" then
					map("K", vim.lsp.buf.hover)
				end
				map("<leader>rn", function()
					local command = ":IncRename " .. vim.fn.expand("<cword>")
					local function incremental_rename()
						if vim.api.nvim_get_current_buf() == bufnr then
							vim.api.nvim_feedkeys(command, "n", false)
						end
					end
					if vim.bo[bufnr].filetype == "java" then
						local kross = require("kross")
						if kross.rename then
							return kross.rename(nil, { fallback = incremental_rename })
						end
					end
					incremental_rename()
				end)
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

		vim.lsp.config("nushell", {
			capabilities = capabilities,
		})

		vim.lsp.config("bashls", {
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

		local matlab_include = require("config.matlab.toolchain").clang_include_flag()
		vim.lsp.config("clangd", {
			capabilities = capabilities,
			cmd = { "clangd", "--background-index", "--header-insertion=never" },
			init_options = matlab_include and { fallbackFlags = { matlab_include } } or nil,
		})

		vim.lsp.config("rust_analyzer", {
			capabilities = capabilities,
			settings = require("config.rust.lsp"),
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

		local servers = {
			"bashls",
			"clangd",
			"cssls",
			"html",
			"lua_ls",
			"marksman",
			"nushell",
			"rust_analyzer",
			"taplo",
			"texlab",
			"ts_ls",
		}

		if vim.fn.has("win32") == 0 then
			table.insert(servers, "nixd")
		end

		vim.lsp.enable(servers)

		local configured = {}

		local function configure_jsonls()
			if configured.jsonls then
				return
			end
			configured.jsonls = true

			vim.lsp.config("jsonls", {
				capabilities = capabilities,
				settings = {
					json = {
						schemas = require("schemastore").json.schemas(),
						validate = { enable = true },
					},
				},
			})
			vim.lsp.enable("jsonls")
		end

		local function configure_matlab_ls()
			if configured.matlab_ls then
				return
			end
			configured.matlab_ls = true

			require("config.matlab.lsp").setup(capabilities)
			vim.lsp.enable("matlab_ls")
		end

		local function configure_for_filetype(filetype)
			if filetype == "json" or filetype == "jsonc" then
				configure_jsonls()
			elseif filetype == "matlab" then
				configure_matlab_ls()
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("LspDeferredServerConfig", { clear = true }),
			callback = function(args)
				configure_for_filetype(vim.bo[args.buf].filetype)
			end,
		})

		configure_for_filetype(vim.bo.filetype)
	end,
}
