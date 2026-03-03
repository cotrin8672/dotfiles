return {
  'folke/snacks.nvim',
  enabled = true,
  keys = {
    {
      '<leader>f',
      function()
        require('snacks').terminal.toggle(nil, {
          win = {
            position = 'float',
            width = 0.8,
            height = 0.8,
            border = 'rounded',
          },
        })
      end,
      desc = 'Floating Terminal',
    },
    {
      '<leader>pf',
      function()
        require('snacks').picker.smart({ multi = { 'buffers', 'recent', 'git_files' } })
      end,
      desc = 'Smart Picker (Buffers/Recent/Git Files)',
    },
    {
      '<leader>pp',
      function()
        require('snacks').picker.files({ hidden = false, ignored = true })
      end,
      desc = 'Find Files',
    },
    {
      '<leader>pg',
      function()
        require('snacks').picker.grep({ hidden = true, ignored = false })
      end,
      desc = 'Live Grep',
    },
  },
  opts = {
    bigfile = {
      enabled = true,
    },
    picker = {
      enabled = true,
    },
    quickfile = {
      enabled = true,
    },
    terminal = {
      enabled = true,
      win = {
        wo = {
          winbar = '',
        },
      },
    },
    statuscolumn = {
      enabled = false,
    },
    words = {
      enabled = false,
    },
  },
}
