return {
	"j-hui/fidget.nvim",
	event = "LspAttach",
	opts = {
		progress = {
			poll_rate = 0.5,
			suppress_on_insert = true,
			ignore_done_already = true,
			display = {
				progress_ttl = 3,
				done_ttl = 1,
			},
		},
		notification = {
			override_vim_notify = false,
			window = {
				normal_hl = "Normal",
				winblend = 0,
			},
		},
	},
	config = function(_, opts)
		require("fidget").setup(opts)
	end,
}
