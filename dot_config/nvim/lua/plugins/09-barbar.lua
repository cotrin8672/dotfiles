return {
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
}
