return {
  'akinsho/toggleterm.nvim',
  version = '*',
  cmd = 'ToggleTerm',
  keys = {
    { '<leader>f', '<cmd>ToggleTerm<cr>' },
  },
  config = function()
    require('toggleterm').setup({
      direction = 'float',
      close_on_exit = false,
      shell = 'C:/Users/combl/scoop/shims/nu.exe',
    })
    vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], { noremap = true, silent = true })
    vim.keymap.set('t', 'jj', [[<C-\><C-n>]], { noremap = true, silent = true })
  end,
}
