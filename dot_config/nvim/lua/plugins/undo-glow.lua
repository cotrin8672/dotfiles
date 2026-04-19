return {
	"y3owk1n/undo-glow.nvim",
	event = "VeryLazy",
	opts = function()
		local fallback = {}
		local ok_everforest, everforest = pcall(require, "everforest")
		local ok_colours, colours = pcall(require, "everforest.colours")

		if ok_everforest and ok_colours then
			local palette = colours.generate_palette(everforest.config, vim.o.background)
			fallback.bg = palette.bg0
			fallback.fg = palette.fg
		else
			local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = true })
			if normal.bg then
				fallback.bg = string.format("#%06x", normal.bg)
			end
			if normal.fg then
				fallback.fg = string.format("#%06x", normal.fg)
			end
		end

		return {
			fallback_for_transparency = fallback,
			animation = {
				enabled = true,
				duration = 300,
				animation_type = "fade",
				window_scoped = true,
			},
			highlights = {
				undo = {
					hl_color = { bg = "DiffDelete" },
				},
				redo = {
					hl_color = { bg = "DiffAdd" },
				},
				paste = {
					hl_color = { bg = "IncSearch" },
				},
				search = {
					hl_color = { bg = "CurSearch" },
				},
				comment = {
					hl_color = { bg = "CursorLine" },
				},
			},
		}
	end,
	keys = {
		{
			"u",
			function()
				require("undo-glow").undo()
			end,
			mode = "n",
			desc = "Undo with highlights",
			noremap = true,
			silent = true,
		},
		{
			"<C-r>",
			function()
				require("undo-glow").redo()
			end,
			mode = "n",
			desc = "Redo with highlights",
			noremap = true,
			silent = true,
		},
		{
			"p",
			function()
				require("undo-glow").paste_below()
			end,
			mode = "n",
			desc = "Paste below with highlights",
			noremap = true,
			silent = true,
		},
		{
			"P",
			function()
				require("undo-glow").paste_above()
			end,
			mode = "n",
			desc = "Paste above with highlights",
			noremap = true,
			silent = true,
		},
	},
	init = function()
		vim.api.nvim_create_autocmd("TextYankPost", {
			desc = "Highlight yanks",
			callback = function()
				require("undo-glow").yank()
			end,
		})

		vim.api.nvim_create_autocmd("CmdlineLeave", {
			desc = "Highlight search cmdline result",
			callback = function()
				require("undo-glow").search_cmd()
			end,
		})
	end,
}
