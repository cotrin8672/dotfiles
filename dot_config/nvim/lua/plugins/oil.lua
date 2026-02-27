return {
  'stevearc/oil.nvim',
  cmd = 'Oil',
  keys = {
    { '-', '<cmd>Oil<cr>', desc = 'Oil: Parent dir' },
    { '<leader>o', '<cmd>Oil --float<cr>', desc = 'Oil: Float' },
    { '<leader>O', '<cmd>Oil<cr>', desc = 'Oil: CWD' },
  },
  opts = {
    default_file_explorer = true,
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ['<CR>'] = 'actions.select',
      ['<C-s>'] = 'actions.select_vsplit',
      ['<C-h>'] = 'actions.select_split',
      ['<C-t>'] = 'actions.select_tab',
      ['-'] = 'actions.parent',
      ['g.'] = 'actions.toggle_hidden',
      ['q'] = 'actions.close',
    },
  },
  dependencies = { 'nvim-tree/nvim-web-devicons' },
}
