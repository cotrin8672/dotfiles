return {
  'ishiooon/codex.nvim',
  event = 'VeryLazy',
  cmd = {
    'Codex',
    'CodexFocus',
    'CodexOpen',
    'CodexClose',
    'CodexSend',
    'CodexTreeAdd',
    'CodexAdd',
    'CodexDiffAccept',
    'CodexDiffDeny',
    'CodexSelectModel',
  },
  keys = {
    { '<leader>ac', '<cmd>Codex<cr>', mode = { 'n', 'i' }, desc = 'Codex: Toggle' },
    { '<leader>af', '<cmd>CodexFocus<cr>', mode = { 'n', 'i' }, desc = 'Codex: Focus' },
    { '<leader>as', '<cmd>CodexSend<cr>', mode = 'v', desc = 'Codex: Send selection' },
    { '<leader>as', '<cmd>CodexTreeAdd<cr>', mode = 'n', ft = { 'neo-tree', 'oil' }, desc = 'Codex: Add file' },
  },
  dependencies = {
    'folke/snacks.nvim',
  },
  opts = {
    keymaps = {
      enabled = false,
    },
    terminal = {
      provider = 'snacks',
      unfocus_key = '<C-w>',
      unfocus_mapping = [[<C-\><C-n><C-w>p]],
    },
  },
}
