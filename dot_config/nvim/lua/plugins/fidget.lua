return {
	"j-hui/fidget.nvim",
	event = { "LspAttach", "VeryLazy" },
	opts = function()
		local default_notification = require("fidget.notification").default_config
		local message_notification = vim.deepcopy(default_notification)
		message_notification.name = nil
		message_notification.icon = nil
		message_notification.info_annote = ""
		message_notification.ttl = 2
		message_notification.skip_history = true

		return {
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
				configs = {
					default = default_notification,
					nvim_message = message_notification,
				},
				window = {
					normal_hl = "Normal",
					winblend = 0,
					y_padding = 1,
				},
			},
		}
	end,
	config = function(_, opts)
		require("fidget").setup(opts)
		require("config.ui2_fidget").setup()
	end,
}
