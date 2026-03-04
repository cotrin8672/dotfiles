local M = {}

M.treesitter_parsers = {
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
}

-- Treesitter language -> lspconfig server name
M.lsp_from_treesitter = {
  bash = 'bashls',
  css = 'cssls',
  html = 'html',
  java = 'jdtls',
  javascript = 'ts_ls',
  json = 'jsonls',
  kotlin = 'kotlin_lsp',
  lua = 'lua_ls',
  rust = 'rust_analyzer',
  toml = 'taplo',
  tsx = 'ts_ls',
  typescript = 'ts_ls',
}

return M
