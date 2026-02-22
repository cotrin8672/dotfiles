return {
  'nvim-telescope/telescope.nvim',
  cmd = 'Telescope',
  keys = {
    {
      '<leader>pf',
      function()
        require('telescope.builtin').find_files()
      end,
    },
    {
      '<leader>pg',
      function()
        require('telescope.builtin').live_grep()
      end,
    },
    {
      '<leader>pb',
      function()
        require('telescope').extensions.file_browser.file_browser()
      end,
    },
    {
      '<leader>pr',
      function()
        require('telescope.builtin').resume()
      end,
    },
    {
      '<leader>pa',
      function()
        require('telescope.builtin').oldfiles()
      end,
    },
  },
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope-file-browser.nvim',
    'nvim-telescope/telescope-ui-select.nvim',
  },
  config = function()
    require('telescope').setup({
      extensions = {
        ['ui-select'] = {},
        file_browser = {},
      },
    })
    require('telescope').load_extension('ui-select')
    require('telescope').load_extension('file_browser')
  end,
}
