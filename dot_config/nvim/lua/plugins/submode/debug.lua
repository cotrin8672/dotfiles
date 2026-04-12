return function(sm)
	local shared = require("plugins.submode.shared")

	local debug_sm = sm.build_submode({
		name = "DEBUG",
		display_name = "DEBUG",
		color = "#B19CD9",
		timeoutlen = vim.o.timeoutlen,
		is_count_enable = false,
		after_enter = function()
			local ok, dapui = pcall(require, "dapui")
			if ok then
				dapui.open()
			end
			shared.refresh_ui()
		end,
		after_leave = function()
			local ok, dapui = pcall(require, "dapui")
			if ok then
				dapui.close()
			end
			shared.refresh_ui()
		end,
	}, {
		{
			"c",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.continue()
				end
				return ""
			end,
		},
		{
			"n",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.step_over()
				end
				return ""
			end,
		},
		{
			"i",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.step_into()
				end
				return ""
			end,
		},
		{
			"o",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.step_out()
				end
				return ""
			end,
		},
		{
			"b",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.toggle_breakpoint()
				end
				return ""
			end,
		},
		{
			"B",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					local condition = vim.fn.input("Breakpoint condition: ")
					if condition ~= nil and condition ~= "" then
						dap.set_breakpoint(condition)
					end
				end
				return ""
			end,
		},
		{
			"l",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.run_last()
				end
				return ""
			end,
		},
		{
			"r",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.repl.toggle()
				end
				return ""
			end,
		},
		{
			"t",
			function()
				local ok, dap = pcall(require, "dap")
				if ok then
					dap.terminate()
				end
				return ""
			end,
		},
		{
			"u",
			function()
				local ok, dapui = pcall(require, "dapui")
				if ok then
					dapui.toggle()
				end
				return ""
			end,
		},
		{ "j", "j" },
		{ "k", "k" },
		{ "h", "h" },
		{ "l", "l" },
		{ "<Tab>", "<Cmd>BufferNext<CR>" },
		{ "<S-Tab>", "<Cmd>BufferPrevious<CR>" },
		{
			"<Esc>",
			function()
				return "", sm.EXIT_SUBMODE
			end,
		},
	})

	vim.keymap.set("n", "<leader>d", function()
		sm.enable(debug_sm)
	end, { desc = "DEBUG submode" })
end
