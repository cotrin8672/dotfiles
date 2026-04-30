return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	dependencies = {
		"lambdalisue/vim-kensaku",
	},
	opts = {
		image = {
			enabled = true,
			doc = {
				enabled = true,
				inline = false,
				float = true,
				conceal = function(lang, type)
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
			preview = function(ctx)
				return require("md-render.snacks").preview()(ctx)
			end,
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
			"<leader>pf",
			function()
				Snacks.picker.files()
			end,
			desc = "Find files",
		},
		{
			"<leader>pg",
			function()
				local sources = require("snacks.picker.config.sources")
				sources.grep_kensaku = require("plugins.snacks-kensaku.grep_kensaku")
				sources.grep_merged = require("plugins.snacks-kensaku.grep_merged")
				Snacks.picker.grep_merged()
			end,
			desc = "Live grep with grep + kensaku.vim",
		},
		{
			"<leader>pb",
			function()
				Snacks.picker.git_branches()
			end,
			desc = "Git branches",
		},
		{
			"<leader>pd",
			function()
				Snacks.picker.diagnostics()
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>ps",
			function()
				Snacks.picker.lsp_symbols()
			end,
			desc = "Document symbols",
		},
		{
			"<leader>pS",
			function()
				Snacks.picker.lsp_workspace_symbols()
			end,
			desc = "Workspace symbols",
		},
		{
			"<leader>pi",
			function()
				Snacks.picker.gh_issue()
			end,
			desc = "Github issues",
		},
		{
			"<leader>pp",
			function()
				Snacks.picker.gh_pr()
			end,
			desc = "Github PR",
		},
	},
}
