return {
	"akinsho/toggleterm.nvim",
	event = "VeryLazy",
	config = function()
		local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
		local normal_float = vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false })
		local float_border = vim.api.nvim_get_hl(0, { name = "FloatBorder", link = false })
		local Terminal = require("toggleterm.terminal").Terminal

		local function hl_color(hl, key, fallback)
			local value = hl and hl[key]
			if value then
				return string.format("#%06x", value)
			end

			return fallback
		end

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

		local function shutdown_toggleterms()
			for _, term in ipairs(require("toggleterm.terminal").get_all(true)) do
				pcall(function()
					term:shutdown()
				end)
			end
		end

		require("toggleterm").setup({
			open_mapping = nil,
			shade_terminals = false,
			direction = "float",
			highlights = {
				Normal = {
					guibg = hl_color(normal_float, "bg", "NONE"),
					guifg = hl_color(normal_float, "fg", hl_color(normal, "fg", nil)),
				},
				NormalFloat = {
					guibg = hl_color(normal_float, "bg", "NONE"),
					guifg = hl_color(normal_float, "fg", hl_color(normal, "fg", nil)),
				},
				FloatBorder = {
					guibg = hl_color(float_border, "bg", hl_color(normal_float, "bg", "NONE")),
					guifg = hl_color(float_border, "fg", hl_color(normal_float, "fg", hl_color(normal, "fg", nil))),
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

		vim.api.nvim_create_autocmd("QuitPre", {
			group = vim.api.nvim_create_augroup("ToggleTermShutdownOnQuit", { clear = true }),
			callback = shutdown_toggleterms,
		})
	end,
}
