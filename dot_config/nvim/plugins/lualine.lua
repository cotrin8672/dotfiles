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
      },
      sections = {
        lualine_x = { 'encoding', 'fileformat', short_ft },
      },
    })
  end,
}
