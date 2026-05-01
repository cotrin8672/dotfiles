return {
	{
		"mason-org/mason.nvim",
		lazy = true,
		opts = {
			PATH = "prepend",
		},
	},
	{
		"mason-org/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = {
			"mason.nvim",
			"neovim/nvim-lspconfig",
		},
		opts = function()
			local ensure_installed = {
				"lua_ls",
				"bashls",
				"jsonls",
				"html",
				"cssls",
				"ts_ls",
				"rust_analyzer",
				"taplo",
				"marksman",
				"texlab",
				"matlab_ls",
			}

			if vim.fn.has("win32") == 0 then
				table.insert(ensure_installed, "nixd")
			end

			return {
				ensure_installed = ensure_installed,
				automatic_enable = {
					exclude = {
						-- kotlin.nvim manages the official kotlin-lsp itself as `kotlin_ls`.
						"kotlin_lsp",
					},
				},
			}
		end,
	},
	{
		name = "mason-tool-installer.nvim",
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		cmd = { "MasonToolsInstall", "MasonToolsUpdate", "MasonToolsClean" },
		dependencies = {
			"mason.nvim",
		},
		opts = {
			ensure_installed = {
				"jdtls",
				"kotlin-lsp",
				"google-java-format",
				"ktfmt",
				"ktlint",
				"prettier",
				"stylua",
				"alejandra",
				"shfmt",
				"eslint-d",
				"shellcheck",
				"markdownlint",
			},
			auto_update = false,
			start_delay = 0,
		},
	},
}
