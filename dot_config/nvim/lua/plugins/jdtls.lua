return {
	"mfussenegger/nvim-jdtls",
	ft = { "java" },
	dependencies = {
		{
			"cotrin8672/mc-dev-lsp",
			name = "mcdev-nvim",
			version = "v0.7.7",
		},
		"neovim/nvim-lspconfig",
		"cotrin8672/kross.nvim",
	},
	config = function()
		local ok, jdtls = pcall(require, "jdtls")
		if not ok then
			return
		end
		local kross = require("kross")
		local root_markers = {
			"gradlew",
			".git",
			"mvnw",
			"pom.xml",
			"build.gradle",
			"build.gradle.kts",
			"settings.gradle",
			"settings.gradle.kts",
		}

		local capabilities = vim.lsp.protocol.make_client_capabilities()

		pcall(function()
			capabilities = require("blink.cmp").get_lsp_capabilities(capabilities)
		end)

		local function start_or_attach(bufnr)
			if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].filetype ~= "java" then
				return
			end

			local source = vim.api.nvim_buf_get_name(bufnr)
			local root_dir = require("jdtls.setup").find_root(root_markers, source)
			if not root_dir or root_dir == "" then
				return
			end

			local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
			local root_hash = vim.fn.sha256(vim.fs.normalize(root_dir)):sub(1, 12)
			local workspace_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "jdtls", project_name .. "-" .. root_hash)
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
					bundles = kross.bundles(),
				},
			}

			if require("mcdev.jdtls").extend_config(config) then
				jdtls.start_or_attach(config, nil, { bufnr = bufnr })
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("JdtlsAttach", { clear = true }),
			pattern = "java",
			callback = function(event)
				start_or_attach(event.buf)
			end,
		})

		start_or_attach(vim.api.nvim_get_current_buf())
	end,
}
