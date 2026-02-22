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
}
