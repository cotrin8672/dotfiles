return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
	},
	opts = {
		cmdline = {
			enabled = true,
			view = "cmdline_popup",
		},
		views = {
			cmdline_popup = {
				position = {
					row = "50%",
					col = "50%",
				},
			},
		},
		lsp = {
			override = {
				["vim.lsp.util.convert_input_to_markdown_lines"] = true,
				["vim.lsp.util.stylize_markdown"] = true,
				["cmp.entry.get_documentation"] = true,
			},
		},
		presets = {
			bottom_search = true,
			command_palette = true,
			long_message_to_split = true,
			inc_rename = false,
			lsp_doc_border = true,
		},
	},
	config = function(_, opts)
		local ok_notify, notify = pcall(require, "notify")
		if ok_notify then
			notify.setup()
			vim.notify = notify
		end

		require("noice").setup(opts)
		vim.api.nvim_set_hl(0, "NoiceCmdlinePopup", { link = "NormalFloat" })
		vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { link = "FloatBorder" })
		vim.api.nvim_set_hl(0, "NoicePopup", { link = "NormalFloat" })
		vim.api.nvim_set_hl(0, "NoicePopupBorder", { link = "FloatBorder" })
	end,
}
