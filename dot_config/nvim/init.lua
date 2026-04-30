vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.g.loaded_matchit = 1
vim.g.loaded_gzip = 1
vim.g.loaded_zipPlugin = 1
vim.g.loaded_tarPlugin = 1
vim.g.loaded_tutor_mode_plugin = 1
vim.g.loaded_2html_plugin = 1
vim.g.loaded_spellfile_plugin = 1
vim.g.loaded_remote_plugins = 1
vim.g.loaded_man = 1
vim.g.loaded_matchparen = 1
vim.g.loaded_nvim_net_plugin = 1
vim.g.loaded_shada_plugin = 1
vim.g.loaded_node_provider = 1
vim.g.loaded_python3_provider = 1
vim.g.loaded_ruby_provider = 1
vim.g.loaded_perl_provider = 1
vim.g.termfeatures = vim.tbl_extend("force", vim.g.termfeatures or {}, { osc52 = false })
vim.g.smart_splits_multiplexer_integration = "wezterm"

if vim.loader then
	vim.loader.enable()
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.keymap.set("i", "<M-o>", "<C-g>u<C-o>o", { desc = "Open line below" })

local float = require("shared.float")
require("config.zenhan").setup({
	command = "zenhan.exe",
	off_arg = "0",
})

if vim.env.WSL_DISTRO_NAME then
	vim.g.clipboard = {
		name = "wsl-clipp",
		copy = {
			["+"] = { "clip.exe" },
			["*"] = { "clip.exe" },
		},
		paste = {
			["+"] = {
				"powershell.exe",
				"-NoProfile",
				"-NoLogo",
				"-Command",
				'[Console]::Out.Write((Get-Clipboard -Raw).Replace("`r", ""))',
			},
			["*"] = {
				"powershell.exe",
				"-NoProfile",
				"-NoLogo",
				"-Command",
				'[Console]::Out.Write((Get-Clipboard -Raw).Replace("`r", ""))',
			},
		},
		cache_enabled = 0,
	}
end

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.clipboard = "unnamedplus"
vim.opt.laststatus = 3
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.autoindent = true
vim.opt.smartindent = true
vim.opt.copyindent = true
vim.opt.preserveindent = true
vim.opt.winborder = "rounded"
vim.opt.pumborder = "rounded"
vim.opt.cursorline = true
vim.opt.winblend = float.blend
vim.opt.belloff = "all"
vim.opt.errorbells = false
vim.opt.visualbell = false
vim.opt.shada = "'10,<5,s1,h"
vim.opt.scrolloff = 10
vim.opt.wrap = false
vim.opt.fillchars.eob = " "
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.virtualedit = "block"
vim.opt.autoread = true

local indent_group = vim.api.nvim_create_augroup("IndentDefaults", { clear = true })

local function set_indent(width)
	return function()
		vim.bo.expandtab = true
		vim.bo.tabstop = width
		vim.bo.softtabstop = width
		vim.bo.shiftwidth = width
	end
end

vim.api.nvim_create_autocmd("FileType", {
	group = indent_group,
	pattern = {
		"bash",
		"css",
		"html",
		"javascript",
		"javascriptreact",
		"json",
		"jsonc",
		"lua",
		"markdown",
		"nix",
		"sh",
		"toml",
		"typescript",
		"typescriptreact",
		"zsh",
	},
	callback = set_indent(2),
})

vim.api.nvim_create_autocmd("FileType", {
	group = indent_group,
	pattern = {
		"java",
		"kotlin",
		"rust",
	},
	callback = set_indent(4),
})

vim.api.nvim_create_autocmd({ "WinEnter", "FocusGained", "BufEnter" }, {
	pattern = "*",
	command = "checktime",
})

require("shared.java_kotlin_package").setup()
vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if not client or client.name ~= "matlab_ls" then
			return
		end

		require("config.matlab").setup()
	end,
})
vim.api.nvim_create_autocmd("User", {
	pattern = "VeryLazy",
	once = true,
	callback = function()
		require("ui.cursor_mode").setup()
	end,
})

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
	local result = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		error("Failed to bootstrap lazy.nvim:\n" .. result)
	end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins", {
	install = { missing = true },
	checker = { enabled = false },
	change_detection = { enabled = false },
})
