return {
  'echasnovski/mini.nvim',
  version = false,
  event = 'VeryLazy',
  config = function()
    local map_opts = { noremap = true, silent = true }
    local MiniClue = require('mini.clue')
    local MiniMisc = require('mini.misc')

    MiniMisc.setup_restore_cursor()
    require('mini.extra').setup()

    MiniClue.setup({
      triggers = {
        { mode = 'n', keys = '<Leader>' },
        { mode = 'x', keys = '<Leader>' },
        { mode = 'n', keys = 'g' },
        { mode = 'x', keys = 'g' },
        { mode = 'n', keys = '[' },
        { mode = 'n', keys = ']' },
        { mode = 'n', keys = '<C-w>' },
        { mode = 'n', keys = 'z' },
        { mode = 'x', keys = 'z' },
      },
      clues = {
        MiniClue.gen_clues.builtin_completion(),
        MiniClue.gen_clues.g(),
        MiniClue.gen_clues.marks(),
        MiniClue.gen_clues.registers(),
        MiniClue.gen_clues.windows(),
        MiniClue.gen_clues.z(),
      },
      window = {
        delay = 300,
      },
    })
    vim.o.timeout = true
    vim.o.timeoutlen = 300

    require('mini.align').setup({
      mappings = {
        start = '<leader>aa',
        start_with_preview = '<leader>aA',
      },
    })
    require('mini.surround').setup()
    require('mini.pairs').setup()
    require('mini.pick').setup()
    require('mini.visits').setup()
    require('mini.trailspace').setup()

    vim.keymap.set('n', '<leader>pf', function()
      require('mini.pick').builtin.files()
    end, vim.tbl_extend('force', map_opts, { desc = 'Find Files' }))

    vim.keymap.set('n', '<leader>pg', function()
      require('mini.pick').builtin.grep_live()
    end, vim.tbl_extend('force', map_opts, { desc = 'Live Grep' }))

    vim.keymap.set('n', '<leader>pb', function()
      require('mini.pick').builtin.buffers()
    end, vim.tbl_extend('force', map_opts, { desc = 'Search Buffers' }))

    vim.keymap.set('n', '<leader>pr', function()
      require('mini.extra').pickers.visit_paths()
    end, vim.tbl_extend('force', map_opts, { desc = 'Recent Files' }))

    vim.keymap.set('n', '<leader>ps', function()
      require('mini.extra').pickers.lsp({ scope = 'workspace_symbol' })
    end, vim.tbl_extend('force', map_opts, { desc = 'LSP Workspace Symbols' }))
  end,
}
