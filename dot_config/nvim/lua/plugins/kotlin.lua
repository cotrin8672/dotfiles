return {
	"AlexandrosAlexiou/kotlin.nvim",
	-- Keep the pre-v2 launcher path (kotlin-lsp/java), not bin/intellij-server.
	version = "v1.1.0",
	ft = { "kotlin" },
	dependencies = {
		"neovim/nvim-lspconfig",
		"stevearc/oil.nvim",
		"folke/trouble.nvim",
	},
	config = function()
		require("kotlin").setup({
			root_markers = {
				"gradlew",
				".git",
				"mvnw",
				"settings.gradle",
				"settings.gradle.kts",
			},
			jdk_for_symbol_resolution = os.getenv("JAVA_HOME"),
			jvm_args = {
				"-Xmx4g",
			},
			inlay_hints = {
				enabled = true,
			},
			file_templates = {
				enabled = false,
			},
		})
	end,
}
