vim.g.mapleader = " "

local config_root = vim.fn.getcwd() .. "/dot_config/nvim"
local data_root = vim.fn.stdpath("data")

vim.opt.runtimepath:prepend(config_root)
vim.opt.runtimepath:append(data_root .. "/lazy/plenary.nvim")
vim.opt.runtimepath:append(data_root .. "/lazy/nvim-treesitter")

package.path = table.concat({
	config_root .. "/lua/?.lua",
	config_root .. "/lua/?/init.lua",
	package.path,
}, ";")

vim.cmd("runtime plugin/plenary.vim")
