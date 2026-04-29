return {
	"rachartier/tiny-code-action.nvim",
	event = "LspAttach",
	dependencies = {
		"folke/snacks.nvim",
	},
	opts = {
		-- `delta` emits ANSI sequences that show up raw in the snacks preview on Windows.
		backend = "vim",
		picker = "snacks",
		notify = {
			enabled = true,
			on_empty = true,
		},
		signs = {
			quickfix = { "", { link = "DiagnosticWarning" } },
			others = { "", { link = "DiagnosticWarning" } },
			refactor = { "", { link = "DiagnosticInfo" } },
			["refactor.move"] = { "󰪹", { link = "DiagnosticInfo" } },
			["refactor.extract"] = { "", { link = "DiagnosticError" } },
			["source.organizeImports"] = { "", { link = "DiagnosticWarning" } },
			["source.fixAll"] = { "󰃢", { link = "DiagnosticError" } },
			["source"] = { "", { link = "DiagnosticError" } },
			["rename"] = { "󰑕", { link = "DiagnosticWarning" } },
			["codeAction"] = { "", { link = "DiagnosticWarning" } },
		},
	},
	keys = {
		{
			"gra",
			function()
				require("tiny-code-action").code_action({})
			end,
			mode = { "n", "x" },
			desc = "LSP Code Action",
		},
	},
}
