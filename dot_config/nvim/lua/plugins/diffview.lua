return {
	"sindrets/diffview.nvim",
	cmd = {
		"DiffviewOpen",
		"DiffviewFileHistory",
		"DiffviewClose",
	},
	dependencies = {
		"plenary.nvim",
	},
	opts = {
		hooks = {
			view_post_layout = function(view)
				local layout = view.cur_layout
				local RevType = require("diffview.vcs.rev").RevType

				if not (view.left and view.right and view.left.type == RevType.STAGE and view.right.type == RevType.LOCAL) then
					return
				end
				if not (layout and layout.name == "diff2_horizontal" and layout.a and layout.b) then
					return
				end
				if not (vim.api.nvim_win_is_valid(layout.a.id) and vim.api.nvim_win_is_valid(layout.b.id)) then
					return
				end

				local a_col = vim.api.nvim_win_get_position(layout.a.id)[2]
				local b_col = vim.api.nvim_win_get_position(layout.b.id)[2]
				if a_col < b_col then
					vim.api.nvim_win_call(layout.a.id, function()
						vim.cmd("wincmd x")
					end)
				end
			end,
		},
	},
	keys = {
		{
			"<leader>gd",
			function()
				local view = require("diffview.lib").get_current_view()
				if view then
					vim.cmd("DiffviewClose")
				else
					vim.cmd("DiffviewOpen")
				end
			end,
			desc = "Diffview Toggle",
		},
		{
			"<leader>gh",
			"<cmd>DiffviewFileHistory %<cr>",
			desc = "File History",
		},
	},
}
