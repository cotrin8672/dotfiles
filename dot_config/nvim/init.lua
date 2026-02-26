-- Disable unused builtin plugins early.
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
vim.g.loaded_node_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0

local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git',
    'clone',
    '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable',
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
local init_source = debug.getinfo(1, 'S').source
if type(init_source) == 'string' and init_source:sub(1, 1) == '@' then
  local init_path = vim.fn.fnamemodify(init_source:sub(2), ':p')
  local real_init = (vim.uv or vim.loop).fs_realpath(init_path) or init_path
  local config_dir = vim.fn.fnamemodify(real_init, ':h')
  vim.opt.rtp:prepend(config_dir)
end

if vim.loader then
  vim.loader.enable()
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.cursorcolumn = true
vim.opt.termguicolors = true
vim.opt.updatetime = 300
vim.opt.signcolumn = 'yes'
vim.opt.clipboard = 'unnamedplus'
vim.opt.laststatus = 3

if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
  vim.g.sqlite_clib_path = vim.fn.stdpath('data') .. '/sqlite/sqlite3.dll'
end

local function run_silent(cmd)
  if vim.system then
    vim.system(cmd, { text = false }, function() end)
    return
  end
  vim.fn.jobstart(cmd, { detach = true })
end

local function ime_off()
  local is_windows = vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1
  local is_wsl = vim.fn.has('wsl') == 1

  if is_windows or is_wsl then
    local zenhan = vim.g.zenhan_exe_path or 'zenhan.exe'
    if vim.fn.executable(zenhan) == 1 then
      run_silent({ zenhan, '0' })
    end
    return
  end

  if vim.fn.executable('fcitx5-remote') == 1 then
    run_silent({ 'fcitx5-remote', '-c' })
    return
  end
  if vim.fn.executable('fcitx-remote') == 1 then
    run_silent({ 'fcitx-remote', '-c' })
    return
  end
  if vim.fn.executable('ibus') == 1 then
    run_silent({ 'ibus', 'engine', 'xkb:us::eng' })
  end
end

vim.api.nvim_create_autocmd('FocusGained', {
  callback = ime_off,
})
vim.api.nvim_create_autocmd('User', {
  pattern = 'VeryLazy',
  once = true,
  callback = function()
    vim.api.nvim_create_autocmd('InsertLeave', {
      callback = ime_off,
    })
  end,
})

vim.keymap.set('i', 'jj', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('t', 'jj', [[<C-\><C-n>]], { noremap = true, silent = true })
vim.keymap.set('n', '<M-h>', '<C-w>h', { noremap = true, silent = true })
vim.keymap.set('n', '<M-j>', '<C-w>j', { noremap = true, silent = true })
vim.keymap.set('n', '<M-k>', '<C-w>k', { noremap = true, silent = true })
vim.keymap.set('n', '<M-l>', '<C-w>l', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>x', '<Cmd>BufferClose<CR>', { noremap = true, silent = true })

vim.api.nvim_create_autocmd('VimEnter', {
  once = true,
  callback = function()
    require('ui.cursor_mode').setup()
  end,
})

require('lazy').setup({
  spec = {
    { import = 'plugins' },
  },
  change_detection = {
    enabled = false,
    notify = false,
  },
})
