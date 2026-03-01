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
  opts = function()
    local ok, icons = pcall(require, 'ui.diagnostic_icons')
    if not ok then
      icons = require('shared.diagnostic_icons')
    end
    return {
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
          [vim.diagnostic.severity.ERROR] = { enabled = true, icon = icons.error_icon },
          [vim.diagnostic.severity.WARN] = { enabled = false, icon = icons.warn_icon },
          [vim.diagnostic.severity.INFO] = { enabled = false, icon = icons.info_icon },
          [vim.diagnostic.severity.HINT] = { enabled = true, icon = icons.hint_icon },
        },
        gitsigns = {
          added = { enabled = false, icon = '+' },
          changed = { enabled = false, icon = '~' },
          deleted = { enabled = false, icon = '-' },
        },
        filetype = {
          custom_colors = false,
          enabled = true,
        },
        separator = { left = '', right = ' ' },
        separator_at_end = false,
        modified = { button = '●' },
        pinned = { button = '', filename = true },
        preset = 'default',
        alternate = { filetype = { enabled = false } },
        current = { buffer_index = false },
        inactive = {
          button = '',
          separator = { left = '', right = ' ' },
        },
        visible = { modified = { buffer_number = false } },
      },
      insert_at_end = false,
      insert_at_start = false,
      maximum_padding = 1,
      minimum_padding = 1,
      maximum_length = 30,
      minimum_length = 0,
      semantic_letters = true,
      letters = 'asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP',
      no_name_title = nil,
      sort = {
        ignore_case = true,
      },
    }
  end,
  config = function(_, opts)
    require('barbar').setup(opts)
    local function apply_barbar_colors()
      local function get_hl(name)
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
        if not ok then
          return nil
        end
        return hl
      end

      local normal = get_hl('Normal') or {}
      local comment = get_hl('Comment') or {}
      local tabline = get_hl('TabLine') or {}
      local tabline_sel = get_hl('TabLineSel') or {}

      local wst = nil
      do
        local ok, base_color = pcall(require, 'wisteria.lib.base_color')
        if ok and base_color and base_color.wst then
          wst = base_color.wst
        end
      end

      local palette = {
        strip_bg = 'none',
        active_fg = (wst and wst.white) or tabline_sel.fg or normal.fg,
        active_bg = (wst and wst.watarase_blue_dark) or tabline_sel.bg or tabline.bg or normal.bg or 'none',
        visible_fg = (wst and wst.light_gray) or tabline.fg or normal.fg,
        visible_bg = (wst and wst.blue_night) or tabline.bg or normal.bg or 'none',
        inactive_fg = (wst and wst.gray) or comment.fg or tabline.fg or normal.fg,
        inactive_bg = (wst and wst.hanabi_night) or tabline.bg or normal.bg or 'none',
      }

      local by_status = {
        Current = { fg = palette.active_fg, bg = palette.active_bg },
        Visible = { fg = palette.visible_fg, bg = palette.visible_bg },
        Inactive = { fg = palette.inactive_fg, bg = palette.inactive_bg },
        Alternate = { fg = palette.inactive_fg, bg = palette.inactive_bg },
      }

      for status, style in pairs(by_status) do
        local function set(group)
          local hl = get_hl(group)
          if hl then
            vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', hl, {
              fg = style.fg or hl.fg,
              bg = style.bg,
              bold = false,
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
          set('Buffer' .. status .. suffix)
        end

        local left = 'Buffer' .. status .. 'Sign'
        local right = 'Buffer' .. status .. 'SignRight'
        local left_hl = get_hl(left)
        if left_hl then
          vim.api.nvim_set_hl(0, left, vim.tbl_extend('force', left_hl, {
            fg = style.bg ~= 'none' and style.bg or style.fg or left_hl.fg,
            bg = palette.strip_bg,
            bold = false,
            underline = false,
            undercurl = false,
          }))
        end
        local right_hl = get_hl(right)
        if right_hl then
          vim.api.nvim_set_hl(0, right, vim.tbl_extend('force', right_hl, {
            fg = style.bg ~= 'none' and style.bg or style.fg or right_hl.fg,
            bg = palette.strip_bg,
            bold = false,
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
          vim.api.nvim_set_hl(0, group, vim.tbl_extend('force', hl, { bg = palette.strip_bg }))
        end
      end
    end

    apply_barbar_colors()
    vim.api.nvim_create_autocmd('ColorScheme', {
      pattern = '*',
      callback = function()
        require('barbar.highlight').setup()
        apply_barbar_colors()
      end,
    })

    local map = vim.keymap.set
    local key_opts = { noremap = true, silent = true }
    map('n', '<Tab>', '<Cmd>BufferNext<CR>', key_opts)
    map('n', '<S-Tab>', '<Cmd>BufferPrevious<CR>', key_opts)
    map('n', '<leader>x', '<Cmd>BufferClose<CR>', key_opts)
  end,
  version = '^1.0.0',
}
