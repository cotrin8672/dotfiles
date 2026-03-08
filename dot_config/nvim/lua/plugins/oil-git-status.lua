return {
  'refractalize/oil-git-status.nvim',
  dependencies = { 'stevearc/oil.nvim' },
  event = 'VeryLazy',
  config = function()
    require('oil-git-status').setup()
  end,
}
