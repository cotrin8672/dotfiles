return {
	"AlexandrosAlexiou/kotlin.nvim",
	ft = { "kotlin" },
	dependencies = { "neovim/nvim-lspconfig" },
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
