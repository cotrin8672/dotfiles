return {
  'haya14busa/vim-edgemotion',
  keys = {
    { '<C-j>', mode = 'n' },
    { '<C-k>', mode = 'n' },
  },
  config = function()
    local map = vim.keymap.set
    local key_opts = { noremap = true, silent = true }
    map('n', '<C-j>', '<Plug>(edgemotion-j)', key_opts)
    map('n', '<C-k>', '<Plug>(edgemotion-k)', key_opts)
  end,
}
