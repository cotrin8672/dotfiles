return {
  'mfussenegger/nvim-dap',
  event = 'VeryLazy',
  dependencies = {
    {
      'rcarriga/nvim-dap-ui',
      dependencies = { 'nvim-neotest/nvim-nio' },
      config = function()
        require('dapui').setup()
      end,
    },
    {
      'theHamsta/nvim-dap-virtual-text',
      opts = {},
    },
  },
  config = function()
    local _ = require('dap')

    vim.fn.sign_define('DapBreakpoint', {
      text = '',
      texthl = 'DiagnosticSignError',
      linehl = '',
      numhl = '',
    })
    vim.fn.sign_define('DapBreakpointCondition', {
      text = '',
      texthl = 'DiagnosticSignWarn',
      linehl = '',
      numhl = '',
    })
    vim.fn.sign_define('DapBreakpointRejected', {
      text = '',
      texthl = 'DiagnosticSignHint',
      linehl = '',
      numhl = '',
    })
    vim.fn.sign_define('DapLogPoint', {
      text = '󰆈',
      texthl = 'DiagnosticSignInfo',
      linehl = '',
      numhl = '',
    })
    vim.fn.sign_define('DapStopped', {
      text = '',
      texthl = 'DiagnosticSignInfo',
      linehl = 'Visual',
      numhl = '',
    })
  end,
}
