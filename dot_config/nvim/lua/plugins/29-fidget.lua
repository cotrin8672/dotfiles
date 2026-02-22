return {
  'j-hui/fidget.nvim',
  event = 'LspAttach',
  opts = {
    progress = {
      display = {
        progress_ttl = 10,
        done_ttl = 3,
      },
    },
    notification = {
      override_vim_notify = true,
      window = {
        normal_hl = 'Normal',
        winblend = 0,
      },
    },
  },
}
