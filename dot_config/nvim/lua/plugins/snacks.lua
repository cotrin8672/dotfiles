return {
  'folke/snacks.nvim',
  enabled = false,
  keys = {
    {
      '<leader>f',
      function()
        require('snacks').terminal.toggle('nu')
      end,
      desc = 'Toggle Floating Terminal',
    },
  },
  opts = {
    quickfile = {
      enabled = true,
    },
    terminal = {
      enabled = true,
      win = {
        border = 'rounded',
        width = 0.75,
        height = 0.6,
      },
    },
  },
  config = function(_, opts)
    require('snacks').setup(opts)

    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'snacks_terminal',
      callback = function(args)
        local key_opts = { noremap = true, silent = true, buffer = args.buf }
        vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], key_opts)
        vim.keymap.set('t', 'jj', [[<C-\><C-n>]], key_opts)
      end,
    })
  end,
}
