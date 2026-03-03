return {
  'NvChad/nvim-colorizer.lua',
  event = { 'BufReadPre', 'BufNewFile' },
  config = function()
    require('colorizer').setup({
      filetypes = { '*' },
      options = {
        parsers = {
          css = true,
          css_fn = true,
          names = { enable = false },
          hex = {
            rgb = true,
            rgba = true,
            rrggbb = true,
            rrggbbaa = true,
            aarrggbb = true,
          },
          rgb = { enable = true },
          hsl = { enable = true },
        },
      },
    })
  end,
}
