return function(sm)
	local shared = require("plugins.submode.shared")
	local submode_color = "#7DAEA3"

	local window_sm = sm.build_submode({
		name = "WINDOW",
		display_name = "WINDOW",
		color = submode_color,
		timeoutlen = vim.o.timeoutlen,
		after_enter = function()
			shared.refresh_ui()
		end,
		after_leave = function()
			shared.refresh_ui()
		end,
	}, {
		{ "h", "<C-w><" },
		{ "j", "<C-w>+" },
		{ "k", "<C-w>-" },
		{ "l", "<C-w>>" },
		{ "<M-h>", "<C-w>h" },
		{ "<M-j>", "<C-w>j" },
		{ "<M-k>", "<C-w>k" },
		{ "<M-l>", "<C-w>l" },
		{ "s", "<C-w>s" },
		{ "v", "<C-w>v" },
		{ "x", "<C-w>c" },
		{
			"<Esc>",
			function()
				return "", sm.EXIT_SUBMODE
			end,
		},
	})

	vim.keymap.set("n", "<leader>w", function()
		sm.enable(window_sm)
	end, { desc = "Window submode" })
end
