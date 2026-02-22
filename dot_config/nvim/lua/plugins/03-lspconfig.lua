return {
  'neovim/nvim-lspconfig',
  event = 'BufReadPre',
  config = function()
    local function ts_root_dir(bufnr, on_dir)
      local fname = vim.api.nvim_buf_get_name(bufnr)
      on_dir(vim.fs.root(fname, { 'tsconfig.json', 'package.json', 'jsconfig.json' }))
    end
    local function ts_cmd()
      if vim.fn.executable('typescript-language-server') == 1 then
        return { 'typescript-language-server', '--stdio' }
      end
      local bin = vim.fn.fnamemodify('node_modules/typescript-language-server/lib/cli.mjs', ':p')
      if (vim.uv or vim.loop).fs_stat(bin) then
        return { 'node', bin, '--stdio' }
      end
      return { 'pnpm', 'exec', 'typescript-language-server', '--stdio' }
    end

    vim.lsp.config('rust_analyzer', {
      settings = {
        ['rust-analyzer'] = {
          cargo = { allFeatures = true },
          checkOnSave = { command = 'clippy' },
        },
      },
    })

    vim.lsp.config('ts_ls', {
      cmd = ts_cmd(),
      root_dir = ts_root_dir,
      single_file_support = true,
      on_new_config = function(new_config, root_dir)
        new_config.cmd_cwd = root_dir
      end,
    })
    vim.lsp.config('kotlin_lsp', {
      cmd = { 'kotlin-lsp' },
    })

    vim.lsp.enable({
      'rust_analyzer',
      'ts_ls',
      'html',
      'cssls',
      'lua_ls',
      'kotlin_lsp',
      'jdtls',
      'taplo',
      'jsonls',
      'marksman',
      'gradle_ls',
      'biome',
    })
    vim.api.nvim_create_autocmd('LspAttach', {
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
          return
        end

        local key_opts = { noremap = true, silent = true, buffer = args.buf }
        vim.keymap.set('n', 'gd', '<cmd>Lspsaga goto_definition<cr>', key_opts)
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, key_opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, key_opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, key_opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, key_opts)
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, key_opts)
        vim.keymap.set('n', '<leader>ca', '<cmd>Lspsaga code_action<cr>', key_opts)
        vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, key_opts)
        vim.keymap.set('n', ']d', vim.diagnostic.goto_next, key_opts)
        vim.keymap.set('n', '<leader>de', vim.diagnostic.open_float, key_opts)
        vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, key_opts)

        if client.name == 'rust_analyzer' and client.supports_method('textDocument/formatting') then
          vim.api.nvim_create_autocmd('BufWritePre', {
            buffer = args.buf,
            callback = function()
              vim.lsp.buf.format({ async = false })
            end,
          })
        end
      end,
    })
  end,
}
