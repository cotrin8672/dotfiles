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
		{ "h", "<Cmd>vertical resize -1<CR>" },
		{ "j", "<Cmd>resize +1<CR>" },
		{ "k", "<Cmd>resize -1<CR>" },
		{ "l", "<Cmd>vertical resize +1<CR>" },
		{ "<M-h>", "<Cmd>wincmd h<CR>" },
		{ "<M-j>", "<Cmd>wincmd j<CR>" },
		{ "<M-k>", "<Cmd>wincmd k<CR>" },
		{ "<M-l>", "<Cmd>wincmd l<CR>" },
		{ "s", "<Cmd>split<CR>" },
		{ "v", "<Cmd>vsplit<CR>" },
		{ "x", "<Cmd>close<CR>" },
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
