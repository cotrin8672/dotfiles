local float = require("shared.float")

local MD_RENDER_PRELOAD_DELAY = 1500
local md_render_preview

local function get_md_render_preview()
	if not md_render_preview then
		md_render_preview = require("md-render.snacks").preview()
	end
	return md_render_preview
end

local function schedule_md_render_preload()
	local preload = function()
		vim.defer_fn(function()
			pcall(get_md_render_preview)
		end, MD_RENDER_PRELOAD_DELAY)
	end

	if vim.v.vim_did_enter == 1 then
		preload()
		return
	end

	local group = vim.api.nvim_create_augroup("SnacksPickerWarmup", { clear = true })
	vim.api.nvim_create_autocmd("UIEnter", {
		group = group,
		once = true,
		callback = preload,
	})
end

local function open_picker(source, opts)
	opts = vim.tbl_deep_extend("force", {
		find = false,
		show_delay = 0,
	}, opts or {})

	local picker = Snacks.picker(source, opts)
	picker:show()
	picker:find()
	return picker
end

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

local function enable_kitty_placeholders_for_wezterm()
	local is_wezterm = vim.env.TERM_PROGRAM == "WezTerm"
		or vim.env.WEZTERM_EXECUTABLE ~= nil
		or vim.env.WEZTERM_PANE ~= nil
	if not is_wezterm then
		return
	end

	-- Make detection deterministic even when TERM_PROGRAM is not forwarded.
	vim.env.SNACKS_WEZTERM = "true"

	-- This WezTerm fork implements Kitty's Unicode placeholder protocol.
	-- Snacks keeps placeholders disabled for upstream WezTerm, so opt in only
	-- for this terminal instead of pretending that every terminal supports it.
	local terminal = require("snacks.image.terminal")
	for _, environment in ipairs(terminal.envs()) do
		if environment.name == "wezterm" then
			environment.placeholders = true
		end
	end

	-- Snacks currently sends the loop index instead of the actual placement ID
	-- when deleting Unicode-placeholder placements. Keep the workaround in our
	-- config so the plugin checkout remains clean and can still be updated.
	local image = require("snacks.image.image")
	function image:del(pid)
		for _, placement_id in ipairs(pid and { pid } or vim.tbl_keys(self.placements)) do
			if self.placements[placement_id] then
				terminal.request({ a = "d", d = "i", i = self.id, p = placement_id })
				self.placements[placement_id] = nil
			end
		end

		if not next(self.placements) then
			terminal.request({ a = "d", d = "i", i = self.id })
		end
	end
end

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	config = function(_, opts)
		enable_kitty_placeholders_for_wezterm()
		require("snacks").setup(opts)
		schedule_md_render_preload()
	end,
	opts = {
		image = {
			enabled = true,
			doc = {
				enabled = true,
				inline = true,
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
			show_delay = 0,
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
				return get_md_render_preview()(ctx)
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
				open_picker("files")
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
				open_picker("grep_merged")
			end,
			desc = "Live grep with grep + kensaku.vim",
		},
		{
			"<leader>fb",
			function()
				open_picker("git_branches")
			end,
			desc = "Git branches",
		},
		{
			"<leader>fd",
			function()
				open_picker("diagnostics")
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>fs",
			function()
				open_picker("lsp_symbols")
			end,
			desc = "Document symbols",
		},
		{
			"<leader>fS",
			function()
				open_picker("lsp_workspace_symbols")
			end,
			desc = "Workspace symbols",
		},
		{
			"<leader>fi",
			function()
				open_picker("gh_issue")
			end,
			desc = "Github issues",
		},
		{
			"<leader>fp",
			function()
				open_picker("gh_pr")
			end,
			desc = "Github PR",
		},
	},
}
