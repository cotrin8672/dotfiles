return {
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
        'StatusLine',
        'StatusLineNC',
        'FloatBorder',
        'Pmenu',
      }
      for _, group in ipairs(groups) do
        vim.api.nvim_set_hl(0, group, { bg = 'none' })
      end
      vim.api.nvim_set_hl(0, 'WinBar', { bg = 'none', underline = true, italic = false })
      vim.api.nvim_set_hl(0, 'WinBarNC', { bg = 'none', underline = true, italic = false })
    end
    local function apply_line_number_column()
      local ok, base_color = pcall(require, 'wisteria.lib.base_color')
      local bg = '#1E2224'
      local fg = '#BABABA'
      local fg_cursor = '#EFEDE7'
      if ok and base_color and base_color.wst then
        local wst = base_color.wst
        bg = wst.hanabi_night or bg
        fg = wst.gray or fg
        fg_cursor = wst.white or fg_cursor
      end
      vim.api.nvim_set_hl(0, 'LineNr', { fg = fg, bg = bg })
      vim.api.nvim_set_hl(0, 'CursorLineNr', { fg = fg_cursor, bg = bg, bold = true })
    end
    local function apply_cursor_color()
      local ok, base_color = pcall(require, 'wisteria.lib.base_color')
      local cursor_bg = '#9CBBC9' -- sky
      local cursor_fg = '#22272A'
      if ok and base_color and base_color.wst then
        local wst = base_color.wst
        cursor_bg = wst.sky or cursor_bg
        cursor_fg = wst.hanabi_night or cursor_fg
      end
      vim.api.nvim_set_hl(0, 'Cursor', { fg = cursor_fg, bg = cursor_bg })
      vim.api.nvim_set_hl(0, 'lCursor', { fg = cursor_fg, bg = cursor_bg })
      vim.api.nvim_set_hl(0, 'TermCursor', { fg = cursor_fg, bg = cursor_bg })
      vim.api.nvim_set_hl(0, 'TermCursorNC', { fg = cursor_fg, bg = cursor_bg })
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
    apply_line_number_column()
    apply_cursor_color()
    apply_wisteria_tabline()
    vim.api.nvim_create_autocmd('ColorScheme', {
      pattern = '*',
      callback = function()
        apply_transparent_bg()
        apply_line_number_column()
        apply_cursor_color()
        apply_wisteria_tabline()
      end,
    })
    vim.api.nvim_set_hl(0, 'FidgetTitle', { link = 'Title' })
    vim.api.nvim_set_hl(0, 'FidgetTask', { link = 'Normal' })
    vim.api.nvim_set_hl(0, 'FidgetProgress', { link = 'Normal' })
    vim.api.nvim_set_hl(0, 'FidgetIcon', { link = 'Special' })
  end,
}
