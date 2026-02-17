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

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true
vim.opt.updatetime = 300
vim.opt.signcolumn = 'yes'

vim.keymap.set('i', 'jj', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('n', '<M-h>', '<C-w>h', { noremap = true, silent = true })
vim.keymap.set('n', '<M-j>', '<C-w>j', { noremap = true, silent = true })
vim.keymap.set('n', '<M-k>', '<C-w>k', { noremap = true, silent = true })
vim.keymap.set('n', '<M-l>', '<C-w>l', { noremap = true, silent = true })

require('lazy').setup({
  {
    'masisz/wisteria.nvim',
    name = 'wisteria',
    lazy = false,
    priority = 1000,
    opts = {
      transparent = true,
    },
    config = function(_, opts)
      require('wisteria').setup(opts)
      vim.cmd('colorscheme wisteria')
    end,
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'williamboman/mason.nvim', config = true },
      { 'williamboman/mason-lspconfig.nvim' },
    },
    config = function()
      require('mason-lspconfig').setup({
        ensure_installed = {
          'rust_analyzer',
          'ts_ls',
        },
      })

      vim.lsp.config('rust_analyzer', {
        settings = {
          ['rust-analyzer'] = {
            cargo = { allFeatures = true },
            checkOnSave = { command = 'clippy' },
          },
        },
      })

      vim.lsp.config('ts_ls', {
        root_dir = function(fname)
          return vim.fs.root(fname, { 'tsconfig.json', 'package.json', 'jsconfig.json', '.git' })
        end,
        single_file_support = true,
      })

      vim.lsp.enable({ 'rust_analyzer', 'ts_ls' })
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client or client.name ~= 'rust_analyzer' then
            return
          end
          if client.supports_method('textDocument/formatting') then
            vim.api.nvim_create_autocmd('BufWritePre', {
              buffer = args.buf,
              callback = function()
                vim.lsp.buf.format({ async = false })
              end,
            })
          end
        end,
      })
    end,
  },
  {
    'akinsho/toggleterm.nvim',
    version = '*',
    config = function()
      require('toggleterm').setup({})
      vim.keymap.set('n', '<leader>tt', '<cmd>ToggleTerm<cr>', { noremap = true, silent = true })
    end,
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    config = function()
      require('neo-tree').setup({})
      vim.keymap.set('n', '<leader>e', '<cmd>Neotree toggle<cr>', { noremap = true, silent = true })
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
    },
    config = function()
      require('lualine').setup({
        options = {
          theme = 'wisteria',
        },
      })
    end,
  },
  {
    'shellRaining/hlchunk.nvim',
    lazy = false,
    config = function()
      require('hlchunk').setup({
        indent = {
          enable = true,
        },
        chunk = {
          enable = false,
        },
        line_num = {
          enable = false,
        },
        blank = {
          enable = true,
          chars = {
            ' ',
          },
          style = {
            { bg = '#434437' },
            { bg = '#2f4440' },
            { bg = '#433054' },
            { bg = '#284251' },
          },
        },
      })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter',
    lazy = false,
    build = ':TSUpdate',
    config = function()
      local ok, configs = pcall(require, 'nvim-treesitter.configs')
      if not ok then
        return
      end
      configs.setup({
        ensure_installed = {
          'bash',
          'css',
          'html',
          'java',
          'javascript',
          'json',
          'kotlin',
          'lua',
          'rust',
          'toml',
          'tsx',
          'typescript',
        },
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
      })
    end,
  },
})
