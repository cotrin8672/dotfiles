return {
  'folke/trouble.nvim',
  cmd = 'Trouble',
  keys = {
    {
      '<leader>tt',
      '<cmd>Trouble diagnostics toggle<cr>',
      desc = 'Diagnostics (Trouble)',
    },
    {
      '<leader>tq',
      '<cmd>Trouble qflist toggle<cr>',
      desc = 'Quickfix (Trouble)',
    },
    {
      '<leader>tr',
      '<cmd>Trouble lsp_references toggle<cr>',
      desc = 'References (Trouble)',
    },
  },
  opts = {
    focus = true,
    follow = true,
    auto_close = false,
    auto_preview = false,
    warn_no_results = false,
    keys = {
      ['<cr>'] = 'jump_close',
    },
    modes = {
      lsp_submode_references = {
        mode = 'lsp_references',
        win = {
          position = { 0.5, 0.82 },
          size = {
            width = 0.5,
            height = 0.35,
          },
        },
      },
      lsp_submode_diagnostics = {
        mode = 'diagnostics',
        win = {
          position = { 0.5, 0.82 },
          size = {
            width = 0.5,
            height = 0.35,
          },
        },
      },
    },
    win = {
      type = 'float',
      relative = 'editor',
      border = 'rounded',
      title = ' Trouble ',
      title_pos = 'center',
      size = {
        width = 0.65,
        height = 0.5,
      },
      position = { 0.5, 0.5 },
    },
  },
}
