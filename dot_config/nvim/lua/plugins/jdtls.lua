return {
	"mfussenegger/nvim-jdtls",
	ft = { "java" },
	dependencies = {
		"mcdev-nvim",
		"neovim/nvim-lspconfig",
	},
	config = function()
		local ok, jdtls = pcall(require, "jdtls")
		if not ok then
			return
		end

		local root_dir = require("jdtls.setup").find_root({
			"gradlew",
			".git",
			"mvnw",
			"pom.xml",
			"build.gradle",
			"build.gradle.kts",
			"settings.gradle",
			"settings.gradle.kts",
		})

		if not root_dir or root_dir == "" then
			return
		end

		local capabilities = vim.lsp.protocol.make_client_capabilities()

		pcall(function()
			capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
		end)

		local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
		local workspace_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "jdtls", project_name)

		local config = {
			cmd = {
				"jdtls",
				"-data",
				workspace_dir,
			},
			root_dir = root_dir,
			capabilities = capabilities,
			settings = {
				java = {
					format = {
						enabled = false,
					},
				},
			},
			init_options = {
				bundles = {},
			},
		}

		if require("mcdev.jdtls").extend_config(config) then
			jdtls.start_or_attach(config)
		end
	end,
}
