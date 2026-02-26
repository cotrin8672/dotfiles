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
    local function open_references_floating(items, title)
      items = items or {}
      if #items == 0 then
        vim.notify('No references found', vim.log.levels.INFO)
        return
      end

      if #items == 1 then
        vim.cmd(('edit %s'):format(vim.fn.fnameescape(items[1].filename)))
        vim.api.nvim_win_set_cursor(0, { items[1].lnum, math.max((items[1].col or 1) - 1, 0) })
        return
      end

      local lines = {}
      for i, item in ipairs(items) do
        local text = (item.text or ''):gsub('^%s+', '')
        lines[i] = string.format('%d. %s:%d:%d %s', i, vim.fn.fnamemodify(item.filename, ':.'), item.lnum, item.col, text)
      end

      local fbuf = vim.api.nvim_create_buf(false, true)
      vim.bo[fbuf].buftype = 'nofile'
      vim.bo[fbuf].bufhidden = 'wipe'
      vim.bo[fbuf].swapfile = false
      vim.bo[fbuf].modifiable = true
      vim.api.nvim_buf_set_lines(fbuf, 0, -1, false, lines)
      vim.bo[fbuf].modifiable = false

      local width = math.max(60, math.floor(vim.o.columns * 0.75))
      local height = math.min(#lines + 2, math.max(8, math.floor(vim.o.lines * 0.45)))
      local fwin = vim.api.nvim_open_win(fbuf, true, {
        relative = 'editor',
        style = 'minimal',
        border = 'rounded',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2) - 1,
        col = math.floor((vim.o.columns - width) / 2),
        title = string.format(' %s ', title or 'LSP References'),
        title_pos = 'center',
      })
      vim.wo[fwin].cursorline = true

      local function jump_to_selected()
        local idx = vim.api.nvim_win_get_cursor(fwin)[1]
        local choice = items[idx]
        if not choice then
          return
        end
        if vim.api.nvim_win_is_valid(fwin) then
          vim.api.nvim_win_close(fwin, true)
        end
        vim.cmd(('edit %s'):format(vim.fn.fnameescape(choice.filename)))
        vim.api.nvim_win_set_cursor(0, { choice.lnum, math.max((choice.col or 1) - 1, 0) })
      end

      vim.keymap.set('n', '<CR>', jump_to_selected, { buffer = fbuf, silent = true })
      vim.keymap.set('n', 'q', function()
        if vim.api.nvim_win_is_valid(fwin) then
          vim.api.nvim_win_close(fwin, true)
        end
      end, { buffer = fbuf, silent = true })
      vim.keymap.set('n', '<Esc>', function()
        if vim.api.nvim_win_is_valid(fwin) then
          vim.api.nvim_win_close(fwin, true)
        end
      end, { buffer = fbuf, silent = true })
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
      commands = {
        ['editor.action.showReferences'] = function(command, ctx)
          local client = vim.lsp.get_client_by_id(ctx.client_id)
          if not client then
            return vim.NIL
          end
          local unpack_fn = table.unpack or unpack
          local _, _, references = unpack_fn(command.arguments or {})
          local items = vim.lsp.util.locations_to_items(references or {}, client.offset_encoding)
          open_references_floating(items, command.title or 'TS References')
          return vim.NIL
        end,
      },
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

        local function pick_references()
          vim.lsp.buf.references(nil, {
            includeDeclaration = false,
            on_list = function(opts)
              open_references_floating(opts.items or {}, 'LSP References')
            end,
          })
        end

        local key_opts = { noremap = true, silent = true, buffer = args.buf }
        vim.keymap.set('n', 'gd', '<cmd>Lspsaga goto_definition<cr>', key_opts)
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, key_opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, key_opts)
        vim.keymap.set('n', 'gr', pick_references, key_opts)
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
