return {
  'rmagatti/auto-session',
  event = 'VeryLazy',
  opts = {
    git_use_branch_name = true,
    auto_create = function()
      local cwd = vim.fn.getcwd()
      return vim.fs.find('.git', { path = cwd, upward = true, type = 'directory' })[1] ~= nil
    end,
    pre_save_cmds = {
      function()
        local cwd = vim.fn.getcwd()
        return vim.fs.find('.git', { path = cwd, upward = true, type = 'directory' })[1] ~= nil
      end,
    },
    session_lens = {
      load_on_setup = false,
    },
  },
}
