return {
  'nvim-treesitter/nvim-treesitter',
  branch = 'master',
  event = { 'BufReadPost', 'BufNewFile' },
  build = ':TSUpdate',
  config = function()
    local ok, configs = pcall(require, 'nvim-treesitter.configs')
    if not ok then
      return
    end
    configs.setup({
      ensure_installed = {
        'bash',
        'css',
        'html',
        'java',
        'javascript',
        'json',
        'kotlin',
        'lua',
        'rust',
        'toml',
        'tsx',
        'typescript',
      },
      auto_install = true,
      highlight = {
        enable = true,
        additional_vim_regex_highlighting = false,
      },
    })
  end,
}
