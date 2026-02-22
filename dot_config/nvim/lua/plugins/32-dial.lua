return {
  'monaqa/dial.nvim',
  keys = {
    { '<C-a>', mode = { 'n', 'x' } },
    { '<C-x>', mode = { 'n', 'x' } },
  },
  config = function()
    local augend = require('dial.augend')
    require('dial.config').augends:register_group({
      default = {
        augend.integer.alias.decimal,
        augend.integer.alias.hex,
        augend.date.alias['%Y/%m/%d'],
        augend.constant.alias.bool,
      },
    })
    local map = vim.keymap.set
    local key_opts = { noremap = true, silent = true }
    map('n', '<C-a>', function()
      require('dial.map').manipulate('increment', 'normal')
    end, key_opts)
    map('n', '<C-x>', function()
      require('dial.map').manipulate('decrement', 'normal')
    end, key_opts)
    map('x', '<C-a>', function()
      require('dial.map').manipulate('increment', 'visual')
    end, key_opts)
    map('x', '<C-x>', function()
      require('dial.map').manipulate('decrement', 'visual')
    end, key_opts)
  end,
}
