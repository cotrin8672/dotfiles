return {
	"akinsho/toggleterm.nvim",
	event = "VeryLazy",
	config = function()
		local normal_float = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
		local float_border = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
		local Terminal = require("toggleterm.terminal").Terminal

		local function attach_close_keymaps(term)
			local opts = { buffer = term.bufnr, silent = true, desc = "Close floating terminal" }

			vim.keymap.set("t", "<Esc>", function()
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true), "n", false)
				term:close()
			end, opts)

			vim.keymap.set("n", "<Esc>", function()
				term:close()
			end, opts)
		end

		require("toggleterm").setup({
			open_mapping = nil,
			shade_terminals = false,
			direction = "float",
			highlights = {
				Normal = {
					guibg = string.format("#%06x", normal_float.bg),
					guifg = string.format("#%06x", normal_float.fg),
				},
				NormalFloat = {
					guibg = string.format("#%06x", normal_float.bg),
					guifg = string.format("#%06x", normal_float.fg),
				},
				FloatBorder = {
					guibg = string.format("#%06x", float_border.bg),
					guifg = string.format("#%06x", float_border.fg),
				},
			},
			float_opts = {
				border = "curved",
				width = math.floor(vim.o.columns * 0.88),
				height = math.floor(vim.o.lines * 0.88),
			},
		})

		local shell = Terminal:new({
			hidden = true,
			direction = "float",
			on_open = attach_close_keymaps,
			float_opts = {
				border = "curved",
				width = math.floor(vim.o.columns * 0.88),
				height = math.floor(vim.o.lines * 0.88),
			},
		})
		local lazygit = Terminal:new({
			cmd = "lazygit",
			hidden = true,
			direction = "float",
			on_open = attach_close_keymaps,
			float_opts = {
				border = "curved",
				width = math.floor(vim.o.columns * 0.88),
				height = math.floor(vim.o.lines * 0.88),
			},
		})

		vim.keymap.set("n", "<leader>f", function()
			shell:toggle()
		end, { desc = "Float Terminal" })

		vim.keymap.set("n", "<leader>gg", function()
			lazygit:toggle()
		end, { desc = "LazyGit Float" })
	end,
}
