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

if vim.fn.executable('npm') == 0 then
  local node_bins = vim.fn.glob(vim.fn.expand('~/.local/share/mise/installs/node/*/bin'), true, true)
  if #node_bins > 0 then
    table.sort(node_bins)
    vim.env.PATH = node_bins[#node_bins] .. ':' .. vim.env.PATH
  end
end

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true
vim.opt.updatetime = 300
vim.opt.signcolumn = 'yes'

vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'tsx', 'jsx' },
  callback = function()
    vim.opt_local.shiftwidth = 2
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.expandtab = true
  end,
})

vim.keymap.set('i', 'jj', '<Esc>', { noremap = true, silent = true })
vim.keymap.set('n', '<M-h>', '<C-w>h', { noremap = true, silent = true })
vim.keymap.set('n', '<M-j>', '<C-w>j', { noremap = true, silent = true })
vim.keymap.set('n', '<M-k>', '<C-w>k', { noremap = true, silent = true })
vim.keymap.set('n', '<M-l>', '<C-w>l', { noremap = true, silent = true })

require('lazy').setup({
  {
    'tpope/vim-sleuth',
    lazy = false,
  },
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
          'html',
          'cssls',
          'lua_ls',
          'kotlin_lsp',
          'jdtls',
          'taplo',
          'jsonls',
          'marksman',
          'gradle_ls',
          'biome',
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

      vim.lsp.enable({
        'rust_analyzer',
        'ts_ls',
        'html',
        'cssls',
        'lua_ls',
        'kotlin_lsp',
        'jdtls',
        'taplo',
        'jsonls',
        'marksman',
        'gradle_ls',
        'biome',
      })
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
      local function short_ft()
        local ft = vim.bo.filetype
        if ft == 'typescriptreact' then
          return 'tsx'
        end
        if ft == 'javascriptreact' then
          return 'jsx'
        end
        return ft
      end

      require('lualine').setup({
        options = {
          theme = 'wisteria',
        },
        sections = {
          lualine_x = { 'encoding', 'fileformat', short_ft },
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
          chars = {
            '│',
          },
        },
        chunk = {
          enable = false,
        },
        line_num = {
          enable = false,
        },
        blank = {
          enable = false,
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
