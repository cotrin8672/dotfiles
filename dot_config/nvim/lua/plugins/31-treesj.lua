return {
  'Wansmer/treesj',
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  keys = {
    { '<leader>s', '<Cmd>TSJToggle<CR>' },
  },
  opts = {
    use_default_keymaps = false,
    check_syntax_error = true,
    max_join_length = 120,
    cursor_behavior = 'hold',
    notify = true,
    dot_repeat = true,
  },
  config = function(_, opts)
    require('treesj').setup(opts)
  end,
}
