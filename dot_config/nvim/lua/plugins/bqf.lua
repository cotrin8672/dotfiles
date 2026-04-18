return {
	"kevinhwang91/nvim-bqf",
	ft = "qf",
	opts = { auto_enable = true,
		preview = {
			auto_preview = true,
		},
		funcmap = {
			vsplit = "",
		},
	},
	config = function(_, opts)
		require("bqf").setup(opts)
		vim.api.nvim_set_hl(0, "BqfPreviewFloat", { link = "NormalFloat" })
		vim.api.nvim_set_hl(0, "BqfPreviewBorder", { link = "FloatBorder" })
	end,
}
