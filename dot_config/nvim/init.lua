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

if vim.loader then
  vim.loader.enable()
end

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.opt.number = true
vim.opt.relativenumber = false
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

vim.api.nvim_create_autocmd({ 'InsertLeave', 'FocusGained' }, {
  callback = ime_off,
})

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
vim.keymap.set('n', '<leader>x', '<Cmd>BufferClose<CR>', { noremap = true, silent = true })

require('lazy').setup({
  {
    'tpope/vim-sleuth',
  },
  {
    'masisz/wisteria.nvim',
    name = 'wisteria',
    priority = 1000,
    event = 'VimEnter',
    opts = {
      transparent = true,
    },
    config = function(_, opts)
      local function apply_transparent_bg()
        local groups = {
          'Normal',
          'NormalNC',
          'NormalFloat',
          'SignColumn',
          'FoldColumn',
          'EndOfBuffer',
          'LineNr',
          'CursorLineNr',
          'StatusLine',
          'StatusLineNC',
          'FloatBorder',
          'Pmenu',
        }
        for _, group in ipairs(groups) do
          vim.api.nvim_set_hl(0, group, { bg = 'none' })
        end
        vim.api.nvim_set_hl(0, 'WinBar', { bg = 'none', underline = true })
        vim.api.nvim_set_hl(0, 'WinBarNC', { bg = 'none', underline = true })
      end
      local function apply_wisteria_tabline()
        local ok, base_color = pcall(require, 'wisteria.lib.base_color')
        if not ok or not base_color or not base_color.wst then
          return
        end
        local wst = base_color.wst
        vim.api.nvim_set_hl(0, 'TabLine', {
          fg = wst.light_gray,
          bg = wst.hanabi_night,
        })
        vim.api.nvim_set_hl(0, 'TabLineSel', {
          fg = wst.white,
          bg = wst.watarase_blue_dark,
          bold = true,
        })
        vim.api.nvim_set_hl(0, 'TabLineFill', {
          fg = wst.gray,
          bg = 'none',
        })
        if package.loaded['barbar.highlight'] then
          require('barbar.highlight').setup()
        end
      end
      require('wisteria').setup(opts)
      vim.cmd('colorscheme wisteria')
      apply_transparent_bg()
      apply_wisteria_tabline()
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        callback = function()
          apply_transparent_bg()
          apply_wisteria_tabline()
        end,
      })
      vim.api.nvim_set_hl(0, 'FidgetTitle', { link = 'Title' })
      vim.api.nvim_set_hl(0, 'FidgetTask', { link = 'Normal' })
      vim.api.nvim_set_hl(0, 'FidgetProgress', { link = 'Normal' })
      vim.api.nvim_set_hl(0, 'FidgetIcon', { link = 'Special' })
    end,
  },
  {
    'neovim/nvim-lspconfig',
    event = 'BufReadPre',
    config = function()
      local function ts_root_dir(bufnr, on_dir)
        local fname = vim.api.nvim_buf_get_name(bufnr)
        on_dir(vim.fs.root(fname, { 'tsconfig.json', 'package.json', 'jsconfig.json' }))
      end
      local function ts_cmd()
        if vim.fn.executable('typescript-language-server') == 1 then
          return { 'typescript-language-server', '--stdio' }
        end
        local bin = vim.fn.fnamemodify('node_modules/typescript-language-server/lib/cli.mjs', ':p')
        if (vim.uv or vim.loop).fs_stat(bin) then
          return { 'node', bin, '--stdio' }
        end
        return { 'pnpm', 'exec', 'typescript-language-server', '--stdio' }
      end

      vim.lsp.config('rust_analyzer', {
        settings = {
          ['rust-analyzer'] = {
            cargo = { allFeatures = true },
            checkOnSave = { command = 'clippy' },
          },
        },
      })

      vim.lsp.config('ts_ls', {
        cmd = ts_cmd(),
        root_dir = ts_root_dir,
        single_file_support = true,
        on_new_config = function(new_config, root_dir)
          new_config.cmd_cwd = root_dir
        end,
      })
      vim.lsp.config('kotlin_lsp', {
        cmd = { 'kotlin-lsp' },
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
          if not client then
            return
          end

          local key_opts = { noremap = true, silent = true, buffer = args.buf }
          vim.keymap.set('n', 'gd', '<cmd>Lspsaga goto_definition<cr>', key_opts)
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, key_opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, key_opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, key_opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, key_opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, key_opts)
          vim.keymap.set('n', '<leader>ca', '<cmd>Lspsaga code_action<cr>', key_opts)
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, key_opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, key_opts)
          vim.keymap.set('n', '<leader>de', vim.diagnostic.open_float, key_opts)
          vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, key_opts)

          if client.name == 'rust_analyzer' and client.supports_method('textDocument/formatting') then
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
    cmd = 'ToggleTerm',
    keys = {
      { '<leader>f', '<cmd>ToggleTerm<cr>' },
    },
    config = function()
      require('toggleterm').setup({
        direction = 'float',
        close_on_exit = false,
        shell = 'C:/Users/combl/scoop/shims/nu.exe',
      })
      vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })
      vim.keymap.set('t', 'jj', [[<C-\><C-n>]], { noremap = true, silent = true })
    end,
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    cmd = 'Neotree',
    keys = {
      { '<leader>e', '<cmd>Neotree toggle<cr>' },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    config = function()
      require('neo-tree').setup({})
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
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
    'nvim-telescope/telescope.nvim',
    cmd = 'Telescope',
    keys = {
      {
        '<leader>pf',
        function()
          require('telescope.builtin').find_files()
        end,
      },
      {
        '<leader>pg',
        function()
          require('telescope.builtin').live_grep()
        end,
      },
      {
        '<leader>pb',
        function()
          require('telescope').extensions.file_browser.file_browser()
        end,
      },
      {
        '<leader>pr',
        function()
          require('telescope.builtin').resume()
        end,
      },
      {
        '<leader>pa',
        function()
          require('telescope.builtin').oldfiles()
        end,
      },
    },
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-file-browser.nvim',
      'nvim-telescope/telescope-ui-select.nvim',
    },
    config = function()
      require('telescope').setup({
        extensions = {
          ['ui-select'] = {},
          file_browser = {},
        },
      })
      require('telescope').load_extension('ui-select')
      require('telescope').load_extension('file_browser')
    end,
  },
  {
    'prochri/telescope-all-recent.nvim',
    cmd = 'Telescope',
    dependencies = {
      'nvim-telescope/telescope.nvim',
      'kkharji/sqlite.lua',
    },
    config = function()
      require('telescope-all-recent').setup({})
    end,
  },
  {
    'romgrk/barbar.nvim',
    event = 'VeryLazy',
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
      highlight_inactive_file_icons = true,
      highlight_visible = true,
      icons = {
        buffer_index = false,
        buffer_number = false,
        button = '',
        diagnostics = {
          [vim.diagnostic.severity.ERROR] = { enabled = true, icon = 'E' },
          [vim.diagnostic.severity.WARN] = { enabled = true, icon = 'W' },
          [vim.diagnostic.severity.INFO] = { enabled = false },
          [vim.diagnostic.severity.HINT] = { enabled = true, icon = 'H' },
        },
        gitsigns = {
          added = { enabled = true, icon = ' ' },
          changed = { enabled = true, icon = ' ' },
          deleted = { enabled = true, icon = ' ' },
        },
        filetype = {
          custom_colors = false,
          enabled = true,
        },
        separator = { left = '', right = '' },
        separator_at_end = false,
        modified = { button = '' },
        pinned = { button = '󰐃', filename = false },
        preset = 'powerline',
        alternate = { filetype = { enabled = false } },
        current = { buffer_index = false },
        inactive = { button = '' },
        visible = { modified = { buffer_number = false } },
      },
      insert_at_end = false,
      insert_at_start = false,
      maximum_padding = 1,
      minimum_padding = 1,
      maximum_length = 28,
      letters = 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',
      no_name_title = nil,
      sort = {
        ignore_case = true,
      },
    },
    config = function(_, opts)
      require('barbar').setup(opts)
      local function apply_barbar_separator_transparent_fix()
        local function get_hl(name)
          local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
          if not ok then
            return nil
          end
          return hl
        end

        local by_status = {
          Current = 'BufferCurrent',
          Visible = 'BufferVisible',
          Inactive = 'BufferInactive',
          Alternate = 'BufferAlternate',
        }
        for status, body_group in pairs(by_status) do
          local body = get_hl(body_group)
          local body_bg = body and body.bg or nil
          local function clear_underline(group)
            local hl = get_hl(group)
            if hl then
              vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', hl, {
                underline = false,
                undercurl = false,
              }))
            end
          end

          for _, suffix in ipairs({
            '',
            'ADDED',
            'CHANGED',
            'DELETED',
            'ERROR',
            'WARN',
            'INFO',
            'HINT',
            'Index',
            'Number',
            'Mod',
            'ModBtn',
            'Btn',
            'Pin',
            'PinBtn',
            'Target',
            'Icon',
          }) do
            clear_underline('Buffer' .. status .. suffix)
          end

          if body then
            vim.api.nvim_set_hl(0, body_group, vim.tbl_extend('force', body, {
              underline = false,
              undercurl = false,
            }))
          end
          local left = 'Buffer' .. status .. 'Sign'
          local right = 'Buffer' .. status .. 'SignRight'

          local left_hl = get_hl(left)
          if left_hl then
            vim.api.nvim_set_hl(0, left, vim.tbl_extend('force', left_hl, {
              fg = body_bg or left_hl.fg,
              bg = 'none',
              underline = false,
              undercurl = false,
            }))
          end

          local right_hl = get_hl(right)
          if right_hl then
            vim.api.nvim_set_hl(0, right, vim.tbl_extend('force', right_hl, {
              fg = body_bg or right_hl.fg,
              bg = 'none',
              underline = false,
              undercurl = false,
            }))
          end
        end

        for _, group in ipairs({
          'BufferTabpageFill',
          'BufferTabpages',
          'BufferTabpagesSep',
          'BufferScrollArrow',
        }) do
          local hl = get_hl(group)
          if hl then
            vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', hl, { bg = 'none' }))
          end
        end

        for _, group in ipairs(vim.fn.getcompletion('DevIcon', 'highlight')) do
          local hl = get_hl(group)
          if hl then
            vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', hl, {
              underline = false,
              undercurl = false,
            }))
          end
        end
      end

      apply_barbar_separator_transparent_fix()
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        callback = function()
          require('barbar.highlight').setup()
          apply_barbar_separator_transparent_fix()
        end,
      })
      local map = vim.keymap.set
      local key_opts = { noremap = true, silent = true }
      map('n', '<Tab>', '<Cmd>BufferNext<CR>', key_opts)
      map('n', '<S-Tab>', '<Cmd>BufferPrevious<CR>', key_opts)
    end,
    version = '^1.0.0',
  },
  {
    'shellRaining/hlchunk.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    config = function()
      local ts = require('hlchunk.utils.ts_node_type')
      local function hl_fg(names)
        if type(names) == 'string' then
          names = { names }
        end
        for _, name in ipairs(names) do
          local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
          if ok and hl and hl.fg then
            return string.format('#%06x', hl.fg)
          end
        end
        return nil
      end
      local has_wisteria, wisteria = pcall(require, 'wisteria.lib.base_color')
      local wst = has_wisteria and wisteria.wst or nil
      local chunk_fg_1 = (wst and wst.gray) or hl_fg({ 'IblScope', 'NonText', 'LineNr', 'Comment' })
      local chunk_fg_2 = (wst and wst.light_gray) or hl_fg({ 'IblScope', 'NonText', 'LineNr', 'Comment' })
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
            '|',
          },
        },
        chunk = {
          enable = true,
          priority = 50,
          notify = true,
          style = {
            { fg = chunk_fg_1 },
            { fg = chunk_fg_2 },
          },
          use_treesitter = true,
          chars = {
            horizontal_line = '-',
            vertical_line = '|',
            left_top = '+',
            left_bottom = '+',
            right_arrow = '>',
          },
          textobject = "",
          max_file_size = 1024 * 1024,
          error_sign = true,
          duration = 200,
          delay = 50,
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
    branch = 'master',
    event = { 'BufReadPost', 'BufNewFile' },
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
    'HiPhish/rainbow-delimiters.nvim',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      -- Defaults are sensible; keep explicit config minimal for clarity.
      local rainbow_delimiters = require('rainbow-delimiters')
      ---@type rainbow_delimiters.config
      vim.g.rainbow_delimiters = {
        strategy = {
          [''] = rainbow_delimiters.strategy['global'],
          vim = rainbow_delimiters.strategy['local'],
        },
        query = {
          [''] = 'rainbow-delimiters',
          lua = 'rainbow-blocks',
        },
        highlight = {
          'RainbowDelimiterRed',
          'RainbowDelimiterYellow',
          'RainbowDelimiterBlue',
          'RainbowDelimiterOrange',
          'RainbowDelimiterGreen',
          'RainbowDelimiterViolet',
          'RainbowDelimiterCyan',
        },
      }
    end,
  },
  {
    'RRethy/vim-illuminate',
    event = { 'BufReadPost', 'BufNewFile' },
  },
  {
    'jghauser/mkdir.nvim',
    event = 'BufWritePre',
  },
  {
    'machakann/vim-sandwich',
    keys = {
      { 'sa', mode = { 'n', 'x' } },
      { 'sd', mode = { 'n', 'x' } },
      { 'sr', mode = { 'n', 'x' } },
    },
  },
  {
    'kevinhwang91/nvim-hlslens',
    keys = {
      { 'n', mode = 'n' },
      { 'N', mode = 'n' },
      { '*', mode = 'n' },
      { '#', mode = 'n' },
      { 'g*', mode = 'n' },
      { 'g#', mode = 'n' },
      { '<leader>l', mode = 'n' },
    },
    config = function()
      require('hlslens').setup()
      local kopts = { noremap = true, silent = true }
      vim.api.nvim_set_keymap(
        'n',
        'n',
        [[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
        kopts
      )
      vim.api.nvim_set_keymap(
        'n',
        'N',
        [[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
        kopts
      )
      vim.api.nvim_set_keymap('n', '*', [[*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('n', '#', [[#<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('n', 'g*', [[g*<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('n', 'g#', [[g#<Cmd>lua require('hlslens').start()<CR>]], kopts)
      vim.api.nvim_set_keymap('n', '<leader>l', '<Cmd>noh<CR>', kopts)
    end,
  },
  {
    'kevinhwang91/nvim-bqf',
    ft = 'qf',
    opts = {
      func_map = {
        stoggledown = ']s',
        stoggleup = '[s',
        stogglevm = 'gs',
        stogglebuf = 'gS',
        sclear = 'zS',
      },
    },
  },
  {
    'rmagatti/auto-session',
    lazy = false,
    opts = {
      session_lens = {
        load_on_setup = false,
      },
    },
  },
  {
    'saghen/blink.cmp',
    event = 'InsertEnter',
    version = '1.*',
    dependencies = { 'rafamadriz/friendly-snippets' },
    opts = {
      keymap = { preset = 'default' },
      appearance = { nerd_font_variant = 'mono' },
      completion = { documentation = { auto_show = false } },
      sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
      fuzzy = { implementation = 'prefer_rust_with_warning' },
    },
    opts_extend = { 'sources.default' },
  },
  {
    'dstein64/vim-startuptime',
    cmd = 'StartupTime',
  },
  {
    'folke/which-key.nvim',
    event = 'VeryLazy',
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {},
  },
  {
    'haya14busa/vim-edgemotion',
    keys = {
      { '<C-j>', mode = 'n' },
      { '<C-k>', mode = 'n' },
    },
    config = function()
      local map = vim.keymap.set
      local key_opts = { noremap = true, silent = true }
      map('n', '<C-j>', '<Plug>(edgemotion-j)', key_opts)
      map('n', '<C-k>', '<Plug>(edgemotion-k)', key_opts)
    end,
  },
  {
    'windwp/nvim-ts-autotag',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      require('nvim-ts-autotag').setup({
        opts = {
          enable_close = true,
          enable_rename = true,
          enable_close_on_slash = false,
        },
      })
    end,
  },
  {
    'numToStr/Comment.nvim',
    event = 'VeryLazy',
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
    'JoosepAlviste/nvim-ts-context-commentstring',
    event = 'VeryLazy',
    config = function()
      require('ts_context_commentstring').setup({
        enable_autocmd = false,
      })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-textobjects',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    config = function()
      local ok, configs = pcall(require, 'nvim-treesitter.configs')
      if not ok then
        return
      end
      configs.setup({
        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = {
              ['af'] = '@function.outer',
              ['if'] = '@function.inner',
              ['ac'] = '@class.outer',
              ['ic'] = '@class.inner',
              ['aa'] = '@parameter.outer',
              ['ia'] = '@parameter.inner',
            },
          },
          move = {
            enable = true,
            set_jumps = true,
            goto_next_start = {
              [']m'] = '@function.outer',
              [']]'] = '@class.outer',
            },
            goto_next_end = {
              [']M'] = '@function.outer',
              [']['] = '@class.outer',
            },
            goto_previous_start = {
              ['[m'] = '@function.outer',
              ['[['] = '@class.outer',
            },
            goto_previous_end = {
              ['[M'] = '@function.outer',
              ['[]'] = '@class.outer',
            },
          },
        },
      })
    end,
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = { 'BufReadPost', 'BufNewFile' },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      max_lines = 3,
    },
  },
  {
    'rainbowhxch/accelerated-jk.nvim',
    keys = {
      { 'j', mode = 'n' },
      { 'k', mode = 'n' },
    },
    config = function()
      local map = vim.keymap.set
      local key_opts = { noremap = true, silent = true }
      map('n', 'j', '<Plug>(accelerated_jk_gj)', key_opts)
      map('n', 'k', '<Plug>(accelerated_jk_gk)', key_opts)
    end,
  },
  {
    'j-hui/fidget.nvim',
    event = 'LspAttach',
    opts = {
      progress = {
        display = {
          progress_ttl = 10,
          done_ttl = 3,
        },
      },
      notification = {
        override_vim_notify = true,
        window = {
          normal_hl = 'Normal',
          winblend = 0,
        },
      },
    },
  },
  {
    'nvimdev/lspsaga.nvim',
    event = 'LspAttach',
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-tree/nvim-web-devicons',
    },
    opts = {},
  },
  {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = {
      { '<leader>s', '<Cmd>TSJToggle<CR>' },
    },
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
    end,
  },
  {
    'monaqa/dial.nvim',
    keys = {
      { '<C-a>', mode = { 'n', 'x' } },
      { '<C-x>', mode = { 'n', 'x' } },
    },
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
