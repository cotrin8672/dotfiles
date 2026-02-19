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
vim.opt.clipboard = 'unnamedplus'
vim.opt.laststatus = 3

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
vim.keymap.set('n', 'gd', '<cmd>Lspsaga goto_definition<cr>', { noremap = true, silent = true })
vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, { noremap = true, silent = true })
vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, { noremap = true, silent = true })
vim.keymap.set('n', 'gr', vim.lsp.buf.references, { noremap = true, silent = true })
vim.keymap.set('n', 'K', vim.lsp.buf.hover, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>ca', '<cmd>Lspsaga code_action<cr>', { noremap = true, silent = true })
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, { noremap = true, silent = true })
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { noremap = true, silent = true })
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { noremap = true, silent = true })

require('lazy').setup({
  {
    'tpope/vim-sleuth',
  },
  {
    'masisz/wisteria.nvim',
    name = 'wisteria',
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
    config = function()
      vim.lsp.config('rust_analyzer', {
        settings = {
          ['rust-analyzer'] = {
            cargo = { allFeatures = true },
            checkOnSave = { command = 'clippy' },
          },
        },
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
      require('toggleterm').setup({
        direction = 'float',
        close_on_exit = false,
        shell = 'nu',
      })
      vim.keymap.set('n', '<leader>f', '<cmd>ToggleTerm<cr>', { noremap = true, silent = true })
      vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })
      vim.keymap.set('t', 'jj', [[<C-\><C-n>]], { noremap = true, silent = true })
    end,
  },
  {
    'simeji/winresizer',
    config = function()
      vim.keymap.set('n', '<leader>wr', '<cmd>WinResizerStartResize<cr>', { noremap = true, silent = true })
    end,
  },
  {
    'windwp/nvim-autopairs',
    event = 'InsertEnter',
    config = function()
      require('nvim-autopairs').setup({})
    end,
  },
  {
    'pocco81/auto-save.nvim',
    config = function()
      require('auto-save').setup({})
    end,
  },
  {
    'ray-x/lsp_signature.nvim',
    event = 'LspAttach',
    config = function()
      require('lsp_signature').setup({})
    end,
  },
  {
    'y3owk1n/undo-glow.nvim',
    version = '*',
    event = 'VeryLazy',
    opts = {
      animation = {
        enabled = true,
        duration = 200,
        animation_type = 'fade',
        window_scoped = true,
      },
      priority = 2048 * 3,
    },
    keys = {
      {
        'u',
        function()
          require('undo-glow').undo()
        end,
        mode = 'n',
        desc = 'Undo with glow',
        noremap = true,
      },
      {
        'U',
        function()
          require('undo-glow').redo()
        end,
        mode = 'n',
        desc = 'Redo with glow',
        noremap = true,
      },
      {
        'p',
        function()
          require('undo-glow').paste_below()
        end,
        mode = 'n',
        desc = 'Paste below with glow',
        noremap = true,
      },
      {
        'P',
        function()
          require('undo-glow').paste_above()
        end,
        mode = 'n',
        desc = 'Paste above with glow',
        noremap = true,
      },
      {
        'n',
        function()
          require('undo-glow').search_next()
        end,
        mode = 'n',
        desc = 'Search next with glow',
        noremap = true,
      },
      {
        'N',
        function()
          require('undo-glow').search_prev()
        end,
        mode = 'n',
        desc = 'Search prev with glow',
        noremap = true,
      },
      {
        '*',
        function()
          require('undo-glow').search_star()
        end,
        mode = 'n',
        desc = 'Search word with glow',
        noremap = true,
      },
      {
        '#',
        function()
          require('undo-glow').search_hash()
        end,
        mode = 'n',
        desc = 'Search word backward with glow',
        noremap = true,
      },
    },
  },
  {
    'TaDaa/vimade',
    event = 'VeryLazy',
    config = function()
      require('vimade').setup({
        recipe = { 'default', { animate = false } },
        ncmode = 'windows',
        fadelevel = 0.4,
        tint = {},
        basebg = '',
      })
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
      vim.api.nvim_create_autocmd('VimEnter', {
        callback = function()
          vim.cmd('Neotree show')
        end,
      })
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
    'romgrk/barbar.nvim',
    dependencies = {
      'nvim-tree/nvim-web-devicons',
      'lewis6991/gitsigns.nvim',
    },
    init = function()
      vim.g.barbar_auto_setup = false
    end,
    opts = {
      animation = true,
      auto_hide = false,
      tabpages = true,
      clickable = true,
      focus_on_close = 'left',
      hide = { extensions = false, inactive = false },
      highlight_alternate = false,
      highlight_inactive_file_icons = false,
      highlight_visible = true,
      icons = {
        buffer_index = false,
        buffer_number = false,
        button = '',
        diagnostics = {
          [vim.diagnostic.severity.ERROR] = { enabled = true, icon = 'ﬀ' },
          [vim.diagnostic.severity.WARN] = { enabled = true },
          [vim.diagnostic.severity.INFO] = { enabled = false },
          [vim.diagnostic.severity.HINT] = { enabled = true },
        },
        gitsigns = {
          added = { enabled = true, icon = '+' },
          changed = { enabled = true, icon = '~' },
          deleted = { enabled = true, icon = '-' },
        },
        filetype = {
          custom_colors = false,
          enabled = true,
        },
        separator = { left = '▎', right = '' },
        separator_at_end = true,
        modified = { button = '' },
        pinned = { button = '', filename = true },
        preset = 'default',
        alternate = { filetype = { enabled = false } },
        current = { buffer_index = true },
        inactive = { button = '' },
        visible = { modified = { buffer_number = false } },
      },
      insert_at_end = false,
      insert_at_start = false,
      maximum_padding = 1,
      minimum_padding = 1,
      maximum_length = 30,
      letters = 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',
      no_name_title = nil,
      sort = {
        ignore_case = true,
      },
    },
    config = function(_, opts)
      require('barbar').setup(opts)
      local map = vim.keymap.set
      local key_opts = { noremap = true, silent = true }
      map('n', '<Tab>', '<Cmd>BufferNext<CR>', key_opts)
      map('n', '<S-Tab>', '<Cmd>BufferPrevious<CR>', key_opts)
    end,
    version = '^1.0.0',
  },
  {
    'shellRaining/hlchunk.nvim',
    config = function()
      local ts = require('hlchunk.utils.ts_node_type')
      ts.tsx = {
        'jsx_element',
        'jsx_fragment',
        'jsx_self_closing_element',
        'function_declaration',
        'arrow_function',
        'class_declaration',
        'method_definition',
        '^if',
        '^for',
        '^while',
        'switch_statement',
        'try_statement',
        'catch_clause',
      }
      ts.typescript = ts.typescript or ts.tsx
      require('hlchunk').setup({
        indent = {
          enable = true,
          chars = {
            '│',
          },
        },
        chunk = {
          enable = true,
          priority = 50,
          notify = true,
          style = {
            { fg = "#806d9c" },
            { fg = "#c21f30" },
          },
          use_treesitter = false,
          chars = {
            horizontal_line = "─",
            vertical_line = "│",
            left_top = "╭",
            left_bottom = "╰",
            right_arrow = ">",
          },
          textobject = "",
          max_file_size = 1024 * 1024,
          error_sign = true,
          duration = 0,
          delay = 300,
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
  {
    'numToStr/Comment.nvim',
    dependencies = {
      'JoosepAlviste/nvim-ts-context-commentstring',
    },
    config = function()
      require('ts_context_commentstring').setup({
        enable_autocmd = false,
      })
      require('Comment').setup({
        pre_hook = require('ts_context_commentstring.integrations.comment_nvim').create_pre_hook(),
        toggler = {
          line = '<leader>cc',
          block = '<leader>cb',
        },
        opleader = {
          line = '<leader>c',
          block = '<leader>b',
        },
      })
    end,
  },
  {
    'j-hui/fidget.nvim',
    opts = {
      progress = {
        display = {
          progress_ttl = 10,
          done_ttl = 3,
        },
      },
      notification = {
        override_vim_notify = true,
      },
    },
  },
  {
    'nvimdev/lspsaga.nvim',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {},
  },
  {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      use_default_keymaps = false,
      check_syntax_error = true,
      max_join_length = 120,
      cursor_behavior = 'hold',
      notify = true,
      dot_repeat = true,
    },
    config = function(_, opts)
      require('treesj').setup(opts)
      local map = vim.keymap.set
      local key_opts = { noremap = true, silent = true }
      map('n', '<leader>s', '<Cmd>TSJToggle<CR>', key_opts)
    end,
  },
  {
    'monaqa/dial.nvim',
    config = function()
      local augend = require('dial.augend')
      require('dial.config').augends:register_group({
        default = {
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.date.alias['%Y/%m/%d'],
          augend.constant.alias.bool,
        },
      })
      local map = vim.keymap.set
      local key_opts = { noremap = true, silent = true }
      map('n', '<C-a>', function()
        require('dial.map').manipulate('increment', 'normal')
      end, key_opts)
      map('n', '<C-x>', function()
        require('dial.map').manipulate('decrement', 'normal')
      end, key_opts)
      map('x', '<C-a>', function()
        require('dial.map').manipulate('increment', 'visual')
      end, key_opts)
      map('x', '<C-x>', function()
        require('dial.map').manipulate('decrement', 'visual')
      end, key_opts)
    end,
  },
})
