local float = require("shared.float")

local function apply_picker_winblend(picker)
	local wins = {}
	if picker.layout then
		if picker.layout.root then
			wins[#wins + 1] = picker.layout.root
		end
		vim.list_extend(wins, vim.tbl_values(picker.layout.wins or {}))
		vim.list_extend(wins, vim.tbl_values(picker.layout.box_wins or {}))
	end

	for _, win in ipairs(wins) do
		win.opts.wo.winblend = float.blend
		if win:win_valid() then
			vim.wo[win.win].winblend = float.blend
		end
	end
end

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		image = {
			enabled = true,
			doc = {
				enabled = true,
				inline = false,
				float = true,
				conceal = function(_, type)
					return type == "math"
				end,
			},
			math = {
				enabled = true,
			},
		},
		picker = {
			enabled = true,
			ui_select = true,
			config = function(opts)
				local on_show = opts.on_show
				opts.on_show = function(picker)
					apply_picker_winblend(picker)
					if on_show then
						on_show(picker)
					end
				end
				return opts
			end,
			preview = function(ctx)
				return require("md-render.snacks").preview()(ctx)
			end,
			win = {
				input = {
					keys = {
						["<M-q>"] = { "qflist", mode = { "i", "n" } },
					},
				},
			},
		},
		rename = {
			enabled = true,
		},
		bigfile = {
			enabled = true,
		},
		quickfile = {
			enabled = true,
		},
		profiler = {
			enabled = true,
		},
	},
	keys = {
		{
			"<leader>ff",
			function()
				Snacks.picker.files()
			end,
			desc = "Find files",
		},
		{
			"<leader>fg",
			function()
				require("lazy").load({ plugins = { "vim-kensaku" } })
				local sources = require("snacks.picker.config.sources")
				sources.grep_kensaku = require("plugins.snacks-kensaku.grep_kensaku")
				sources.grep_merged = require("plugins.snacks-kensaku.grep_merged")
				Snacks.picker.grep_merged()
			end,
			desc = "Live grep with grep + kensaku.vim",
		},
		{
			"<leader>fb",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "Git branches",
		},
		{
			"<leader>fd",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>fs",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "Document symbols",
		},
		{
			"<leader>fS",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "Workspace symbols",
		},
		{
			"<leader>fi",
			function()
				Snacks.picker.gh_issue()
			end,
			desc = "Github issues",
		},
		{
			"<leader>fp",
			function()
				Snacks.picker.gh_pr()
			end,
			desc = "Github PR",
		},
	},
}
