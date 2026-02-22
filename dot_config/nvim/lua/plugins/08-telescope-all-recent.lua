return {
  'prochri/telescope-all-recent.nvim',
  cmd = 'Telescope',
  dependencies = {
    'nvim-telescope/telescope.nvim',
    'kkharji/sqlite.lua',
  },
  config = function()
    require('telescope-all-recent').setup({})
  end,
}
