return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  dependencies = {
    'nvim-tree/nvim-web-devicons',
  },
  config = function()
    local sm_ok, sm = pcall(require, 'nvim-submode')
    local mode = require('lualine.utils.mode')

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

    local function submode_label()
      if not sm_ok then
        return mode.get_mode()
      end
      local name = sm.get_submode_name()
      if name and name ~= '' then
        return name
      end
      return mode.get_mode()
    end

    local function submode_bg()
      if not sm_ok then
        return nil
      end
      local color = sm.get_submode_color()
      return color and { bg = color } or nil
    end

    local function submode_fg()
      if not sm_ok then
        return nil
      end
      local color = sm.get_submode_color()
      return color and { fg = color } or nil
    end

    require('lualine').setup({
      options = {
        theme = 'wisteria',
        component_separators = { left = vim.fn.nr2char(0x27E9), right = vim.fn.nr2char(0x27E8) },
        section_separators = { left = '', right = '' },
      },
      sections = {
        lualine_a = {
          { submode_label, color = submode_bg, separator = { left = '', right = '' } },
        },
        lualine_b = {
          {
            'branch',
            icon = '',
            color = submode_fg,
          },
        },
        lualine_x = { 'encoding', 'fileformat', short_ft },
        lualine_y = {
          { 'progress', color = submode_fg },
        },
        lualine_z = {
          { 'location', color = submode_bg, separator = { left = '', right = '' } },
        },
      },
    })
  end,
}
