return {
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
        component_separators = { left = vim.fn.nr2char(0x27E9), right = vim.fn.nr2char(0x27E8) },
      },
      sections = {
        lualine_x = { 'encoding', 'fileformat', short_ft },
      },
    })
  end,
}
