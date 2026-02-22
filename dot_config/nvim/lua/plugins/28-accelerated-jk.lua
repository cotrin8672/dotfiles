return {
  'rainbowhxch/accelerated-jk.nvim',
  keys = {
    { 'j', mode = 'n' },
    { 'k', mode = 'n' },
  },
  config = function()
    local map = vim.keymap.set
    local key_opts = { noremap = true, silent = true }
    map('n', 'j', '<Plug>(accelerated_jk_gj)', key_opts)
    map('n', 'k', '<Plug>(accelerated_jk_gk)', key_opts)
  end,
}
