return {
  'saghen/blink.cmp',
  event = 'InsertEnter',
  version = '1.*',
  dependencies = { 'rafamadriz/friendly-snippets' },
  opts = {
    keymap = {
      preset = 'enter',
      ['<C-j>'] = { 'select_next', 'fallback_to_mappings' },
      ['<C-k>'] = { 'select_prev', 'fallback_to_mappings' },
      ['<C-s>'] = { 'show_signature', 'hide_signature', 'fallback' },
      ['<C-p>'] = false,
      ['<C-n>'] = false,
      ['<Up>'] = false,
      ['<Down>'] = false,
    },
    appearance = { nerd_font_variant = 'mono' },
    completion = { documentation = { auto_show = false } },
    sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
    fuzzy = { implementation = 'prefer_rust_with_warning' },
  },
  opts_extend = { 'sources.default' },
}
