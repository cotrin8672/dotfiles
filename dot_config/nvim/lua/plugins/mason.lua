return {
	{
		"mason-org/mason.nvim",
		init = function()
			local mason_root = vim.env.MASON or vim.fs.joinpath(vim.fn.stdpath("data"), "mason")
			local path_separator = vim.fn.has("win32") == 1 and ";" or ":"
			local mason_bin_prefix = vim.fs.joinpath(mason_root, "bin") .. path_separator

			vim.env.MASON = mason_root
			if not vim.startswith(vim.env.PATH or "", mason_bin_prefix) then
				vim.env.PATH = mason_bin_prefix .. (vim.env.PATH or "")
			end
		end,
		cmd = {
			"Mason",
			"MasonInstall",
			"MasonUninstall",
			"MasonUninstallAll",
			"MasonUpdate",
			"MasonLog",
		},
		opts = {
			PATH = "skip",
			registries = {
				"github:mason-org/mason-registry",
			},
		},
	},
	{
		"mason-org/mason-lspconfig.nvim",
		cmd = { "LspInstall", "LspUninstall" },
		dependencies = {
			"mason.nvim",
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
			auto_update = true,
			start_delay = 0,
		},
	},
}
