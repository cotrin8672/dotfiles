return {
  'echasnovski/mini.nvim',
  version = false,
  event = 'VimEnter',
  config = function()
    local map_opts = { noremap = true, silent = true }
    local MiniStarter = require('mini.starter')
    local has_devicons, devicons = pcall(require, 'nvim-web-devicons')
    local starter_icon_ns = vim.api.nvim_create_namespace('starter_icon_colors')
    local starter_footer_ns = vim.api.nvim_create_namespace('starter_footer_colors')
    local starter_header_ns = vim.api.nvim_create_namespace('starter_header_colors')
    local starter_emphasis_ns = vim.api.nvim_create_namespace('starter_emphasis_colors')
    local starter_path_ns = vim.api.nvim_create_namespace('starter_path_colors')
    local header_hl_cache = {}
    local starter_header_lines = {
      '███╗   ██╗ ███████╗  ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗',
      '████╗  ██║ ██╔════╝ ██╔═══██╗ ██║   ██║ ██║ ████╗ ████║',
      '██╔██╗ ██║ █████╗   ██║   ██║ ██║   ██║ ██║ ██╔████╔██║',
      '██║╚██╗██║ ██╔══╝   ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║',
      '██║ ╚████║ ███████╗ ╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║',
      '╚═╝  ╚═══╝ ╚══════╝  ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝',
    }

    local function header_gradient_hl(char_idx, total_chars)
      local t = (total_chars <= 1) and 0 or (char_idx / (total_chars - 1))
      local r = math.floor(19 + (113 - 19) * t + 0.5)
      local g = math.floor(78 + (178 - 78) * t + 0.5)
      local b = math.floor(94 + (128 - 94) * t + 0.5)
      local hl = string.format('MiniStarterHeaderGrad_%02x%02x%02x', r, g, b)
      if not header_hl_cache[hl] then
        header_hl_cache[hl] = true
        vim.api.nvim_set_hl(0, hl, { fg = string.format('#%02x%02x%02x', r, g, b), bold = true })
      end
      return hl
    end

    local function apply_header_gradient(buf)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      vim.api.nvim_buf_clear_namespace(buf, starter_header_ns, 0, -1)
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local header_idx = 1

      for lnum, line in ipairs(lines) do
        if header_idx > #starter_header_lines then
          break
        end
        local raw = starter_header_lines[header_idx]
        local pad = line:match('^(%s*)' .. vim.pesc(raw))
        if pad then
          local total_chars = vim.fn.strchars(raw)
          for i = 0, total_chars - 1 do
            local start_col = #pad + vim.str_byteindex(raw, i)
            local end_col = #pad + vim.str_byteindex(raw, i + 1)
            vim.api.nvim_buf_add_highlight(
              buf,
              starter_header_ns,
              header_gradient_hl(i, total_chars),
              lnum - 1,
              start_col,
              end_col
            )
          end
          header_idx = header_idx + 1
        end
      end
    end

    local function setup_non_starter()
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
    end

    local function shorten_path(path)
      local p = vim.fn.fnamemodify(path, ':~')
      local parts = vim.split(p, '/', { plain = true, trimempty = true })
      if #parts <= 3 then
        return p
      end
      return string.format('%s/.../%s/%s', parts[1], parts[#parts - 1], parts[#parts])
    end

    local function section_auto_sessions(limit)
      limit = limit or 8
      return function()
        local ok_auto, auto_session = pcall(require, 'auto-session')
        local ok_lib, session_lib = pcall(require, 'auto-session.lib')
        if not ok_auto or not ok_lib then
          return { { name = 'auto-session is not available', action = '', section = '󰆓  Sessions' } }
        end

        local sessions_dir = auto_session.get_root_dir()
        local sessions = session_lib.get_session_list(sessions_dir)
        if #sessions == 0 then
          return { { name = 'No sessions yet', action = '', section = '󰆓  Sessions' } }
        end

        local items = {}
        for _, s in ipairs(vim.list_slice(sessions, 1, limit)) do
          local session_name = s.session_name or ''
          local repo_path = session_name:match('^(.-)|') or session_name
          repo_path = repo_path or session_name
          local full_path = shorten_path(repo_path)
          local dir_name = vim.fn.fnamemodify(repo_path, ':t')
          local display = string.format('%s (%s)', dir_name, full_path)
          table.insert(items, {
            name = string.format('  󰆓  %s', display),
            section = '󰆓  Sessions',
            _icon = '󰆓',
            _icon_hl = 'MiniStarterProjectIcon',
            _emph_text = dir_name,
            _path_text = string.format('(%s)', full_path),
            action = function()
              auto_session.autosave_and_restore(s.session_name)
            end,
          })
        end
        return items
      end
    end

    local function section_recent_files(limit)
      limit = limit or 8
      return function()
        local cwd = vim.fn.getcwd()
        local sep = package.config:sub(1, 1)
        local cwd_prefix = cwd .. sep
        local items = {}

        for _, f in ipairs(vim.v.oldfiles or {}) do
          if vim.fn.filereadable(f) == 1 and vim.startswith(f, cwd_prefix) then
            local basename = vim.fn.fnamemodify(f, ':t')
            local rel = vim.fn.fnamemodify(f, ':.')
            local icon = '󰈙'
            local icon_hl = 'MiniStarterItem'
            if has_devicons then
              local icon_found, icon_hl_found = devicons.get_icon(basename, nil, { default = true })
              if icon_found and icon_found ~= '' then
                icon = icon_found
              end
              if icon_hl_found and icon_hl_found ~= '' then
                icon_hl = icon_hl_found
              end
            end

            table.insert(items, {
              name = string.format('  %s  %s (%s)', icon, basename, shorten_path(rel)),
              section = '  Recent files (current directory)',
              _icon = icon,
              _icon_hl = icon_hl,
              _emph_text = basename,
              _path_text = string.format('(%s)', shorten_path(rel)),
              action = function()
                vim.cmd('edit ' .. vim.fn.fnameescape(f))
              end,
            })
            if #items >= limit then
              break
            end
          end
        end

        if #items == 0 then
          return { { name = 'No recent files in current directory', action = '', section = '  Recent files (current directory)' } }
        end
        return items
      end
    end

    local function section_builtin_actions_with_icon()
      local actions = MiniStarter.sections.builtin_actions()
      for _, item in ipairs(actions) do
        item.section = '  Keymaps'
        if item.name == 'Edit new buffer' then
          item.name = '    Edit new buffer'
          item._icon = ''
          item._icon_hl = 'MiniStarterFileIcon'
        elseif item.name == 'Quit Neovim' then
          item.name = '    Quit Neovim'
          item._icon = ''
          item._icon_hl = 'MiniStarterQuitIcon'
        else
          item.name = string.format('    %s', item.name)
          item._icon = ''
          item._icon_hl = 'MiniStarterKeymapIcon'
        end
      end
      return actions
    end

    MiniStarter.setup({
      evaluate_single = true,
      header = table.concat({
        '███╗   ██╗ ███████╗  ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗',
        '████╗  ██║ ██╔════╝ ██╔═══██╗ ██║   ██║ ██║ ████╗ ████║',
        '██╔██╗ ██║ █████╗   ██║   ██║ ██║   ██║ ██║ ██╔████╔██║',
        '██║╚██╗██║ ██╔══╝   ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║',
        '██║ ╚████║ ███████╗ ╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║',
        '╚═╝  ╚═══╝ ╚══════╝  ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝',
      }, '\n'),
      items = {
        section_auto_sessions(10),
        section_recent_files(8),
        section_builtin_actions_with_icon,
      },
      content_hooks = {
        function(content)
          for _, line in ipairs(content) do
            for _, unit in ipairs(line) do
              if unit.type == 'section' then
                if unit.string:find('Sessions', 1, true) then
                  unit.hl = 'MiniStarterSectionProjects'
                elseif unit.string:find('Recent files', 1, true) then
                  unit.hl = 'MiniStarterSectionRecent'
                elseif unit.string:find('Keymaps', 1, true) then
                  unit.hl = 'MiniStarterSectionKeymaps'
                end
              end
            end
          end
          return content
        end,
        MiniStarter.gen_hook.aligning('center', 'center'),
        function(content)
          local columns = vim.o.columns
          for _, line in ipairs(content) do
            local has_footer = false
            local has_header = false
            local line_text = ''
            for _, unit in ipairs(line) do
              line_text = line_text .. (unit.string or '')
              if unit.type == 'footer' then
                has_footer = true
              elseif unit.type == 'header' then
                has_header = true
              end
            end
            if has_header then
              if line[1] and line[1].string then
                line[1].string = line[1].string:gsub('^%s+', '')
              end
              line_text = ''
              for _, unit in ipairs(line) do
                line_text = line_text .. (unit.string or '')
              end
              local width = vim.fn.strdisplaywidth(line_text)
              local pad = math.max(math.floor((columns - width) / 2), 0)
              if pad > 0 and line[1] then
                line[1].string = string.rep(' ', pad) .. line[1].string
              end
            end
            if has_footer then
              if line[1] and line[1].string then
                line[1].string = line[1].string:gsub('^%s+', '')
              end
              line_text = ''
              for _, unit in ipairs(line) do
                line_text = line_text .. (unit.string or '')
              end
              local width = vim.fn.strdisplaywidth(line_text)
              local pad = math.max(math.floor((columns - width) / 2), 0)
              if pad > 0 and line[1] then
                line[1].string = string.rep(' ', pad) .. line[1].string
              end
            end
          end
          return content
        end,
      },
      footer = function()
        local ms = 0
        local ok_lazy, lazy = pcall(require, 'lazy')
        if ok_lazy and type(lazy.stats) == 'function' then
          local stats = lazy.stats()
          ms = stats.startuptime or 0
          if ms == 0 and type(stats.times) == 'table' then
            ms = stats.times.LazyDone or stats.times.LazyStart or 0
          end
        end
        return string.format('󰓅  Neovim loaded in %.2f ms', ms)
      end,
    })

    local function apply_starter_hl()
      local ok_base, base_color = pcall(require, 'wisteria.lib.base_color')
      local wst = (ok_base and base_color and base_color.wst) and base_color.wst or nil

      vim.opt.termguicolors = true
      vim.api.nvim_set_hl(0, 'MiniStarterItemPrefix', { link = 'MiniStarterItem' })
      vim.api.nvim_set_hl(0, 'MiniStarterSectionProjects', { fg = (wst and wst.watarase_blue) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterSectionRecent', { fg = (wst and wst.icho_green) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterSectionKeymaps', { fg = (wst and wst.omugi_gold) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterProjectIcon', { link = 'Directory' })
      vim.api.nvim_set_hl(0, 'MiniStarterKeymapIcon', { link = 'Special' })
      vim.api.nvim_set_hl(0, 'MiniStarterFileIcon', { link = 'Directory' })
      vim.api.nvim_set_hl(0, 'MiniStarterQuitIcon', { link = 'ErrorMsg' })
      vim.api.nvim_set_hl(0, 'MiniStarterItemEmphasis', { bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterItemPath', { fg = '#6b7280', italic = false })
      vim.api.nvim_set_hl(0, 'MiniStarterFooter', { fg = (wst and wst.sky) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterFooterIcon', { fg = (wst and wst.omugi_gold) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterFooterNumber', { fg = (wst and wst.flower_fuji) or nil, bold = true })
    end

    local function repaint_starter_buffer(buf)
      if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= 'ministarter' then
        return
      end

      apply_header_gradient(buf)
      vim.api.nvim_buf_clear_namespace(buf, starter_icon_ns, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, starter_footer_ns, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, starter_emphasis_ns, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, starter_path_ns, 0, -1)

      local items = MiniStarter.content_to_items(MiniStarter.get_content(buf))
      for _, item in ipairs(items) do
        if item._icon and item._icon_hl and item._line ~= nil and item._start_col ~= nil then
          local icon_col = item._start_col + 2
          local icon_width = vim.fn.strchars(item._icon)
          vim.api.nvim_buf_add_highlight(
            buf,
            starter_icon_ns,
            item._icon_hl,
            item._line,
            icon_col,
            icon_col + icon_width
          )
        end
        if item._emph_text and item._line ~= nil and item._start_col ~= nil and item.name then
          local ss, _ = item.name:find(item._emph_text, 1, true)
          if ss then
            local start_col = item._start_col + (ss - 1)
            local end_col = start_col + vim.fn.strchars(item._emph_text)
            vim.api.nvim_buf_add_highlight(
              buf,
              starter_emphasis_ns,
              'MiniStarterItemEmphasis',
              item._line,
              start_col,
              end_col
            )
          end
        end
        if item._path_text and item._line ~= nil and item._start_col ~= nil and item.name then
          local ss, _ = item.name:find(item._path_text, 1, true)
          if ss then
            local start_col = item._start_col + (ss - 1)
            local end_col = start_col + vim.fn.strchars(item._path_text)
            vim.api.nvim_buf_add_highlight(
              buf,
              starter_path_ns,
              'MiniStarterItemPath',
              item._line,
              start_col,
              end_col
            )
          end
        end
      end

      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      for i, line in ipairs(lines) do
        local s, e = line:find('%d+%.%d+ ms')
        if line:find('Neovim loaded in', 1, true) and s and e then
          local is, ie = line:find('󰓅', 1, true)
          if is and ie then
            vim.api.nvim_buf_add_highlight(buf, starter_footer_ns, 'MiniStarterFooterIcon', i - 1, is - 1, ie)
          end
          vim.api.nvim_buf_add_highlight(buf, starter_footer_ns, 'MiniStarterFooterNumber', i - 1, s - 1, e)
        end
      end
    end

    apply_starter_hl()
    vim.api.nvim_create_autocmd('ColorScheme', {
      callback = apply_starter_hl,
    })

    vim.api.nvim_create_autocmd('VimEnter', {
      callback = function()
        if vim.fn.argc() > 0 then
          return
        end
        if vim.bo.filetype ~= '' or vim.api.nvim_buf_get_name(0) ~= '' then
          return
        end
        MiniStarter.open()
      end,
    })

    vim.api.nvim_create_autocmd('User', {
      pattern = 'MiniStarterOpened',
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        local opts = { noremap = true, silent = true, buffer = buf }
        vim.keymap.set('n', 'j', function()
          MiniStarter.update_current_item('next', buf)
        end, opts)
        vim.keymap.set('n', 'k', function()
          MiniStarter.update_current_item('prev', buf)
        end, opts)

        vim.schedule(function()
          repaint_starter_buffer(buf)
        end)
      end,
    })

    vim.api.nvim_create_autocmd({ 'BufEnter', 'VimResized' }, {
      callback = function(args)
        local buf = args.buf or vim.api.nvim_get_current_buf()
        if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= 'ministarter' then
          return
        end
        vim.schedule(function()
          repaint_starter_buffer(buf)
        end)
      end,
    })

    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      once = true,
      callback = setup_non_starter,
    })
  end,
}
