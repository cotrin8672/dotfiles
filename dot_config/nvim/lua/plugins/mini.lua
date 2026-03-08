return {
  'echasnovski/mini.nvim',
  version = false,
  event = 'VeryLazy',
  init = function()
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        if vim.fn.argc() > 0 then
          return
        end
        if vim.bo.filetype ~= '' or vim.api.nvim_buf_get_name(0) ~= '' then
          return
        end

        vim.g.mini_starter_requested = true
        require('lazy').load({ plugins = { 'mini.nvim' } })
        require('mini.starter').open()
      end,
    })
  end,
  config = function()
    local map_opts = { noremap = true, silent = true }
    local starter_icon_ns = vim.api.nvim_create_namespace('starter_icon_colors')
    local starter_footer_ns = vim.api.nvim_create_namespace('starter_footer_colors')
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

    local function setup_non_starter()
      local MiniClue = require('mini.clue')
      local MiniMisc = require('mini.misc')

      MiniMisc.setup_restore_cursor()

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
      require('mini.visits').setup()
      require('mini.trailspace').setup()
    end

    local function shorten_path(path)
      local p = vim.fn.fnamemodify(path, ':~')
      local sep = package.config:sub(1, 1)
      local parts = vim.split(p, '[/\\]', { trimempty = true })
      if #parts <= 3 then
        return p
      end
      return string.format('%s%s...%s%s%s%s', parts[1], sep, sep, parts[#parts - 1], sep, parts[#parts])
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
            name = display,
            section = '󰆓  Sessions',
            _icon = '󰆓',
            _icon_hl = 'MiniStarterProjectIcon',
            _icon_virtual = true,
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
        local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

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
              name = string.format('%s (%s)', basename, shorten_path(rel)),
              section = '  Recent files (current directory)',
              _icon = icon,
              _icon_hl = icon_hl,
              _icon_virtual = true,
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
      local MiniStarter = require('mini.starter')
      local actions = MiniStarter.sections.builtin_actions()
      table.insert(actions, 1, {
        name = 'Lazy',
        action = 'Lazy',
        section = 'Builtin actions',
      })
      table.insert(actions, 2, {
        name = 'Mason',
        action = 'Mason',
        section = 'Builtin actions',
      })
      table.insert(actions, 3, {
        name = 'Oil',
        action = 'Oil --float',
        section = 'Builtin actions',
      })
      for _, item in ipairs(actions) do
        item.section = '  Keymaps'
        if item.name == 'Lazy' then
          item._icon = '󰒲'
          item._icon_hl = 'MiniStarterKeymapIcon'
          item._icon_virtual = true
        elseif item.name == 'Mason' then
          item._icon = '󱌣'
          item._icon_hl = 'MiniStarterKeymapIcon'
          item._icon_virtual = true
        elseif item.name == 'Oil' then
          item._icon = '󱧶'
          item._icon_hl = 'MiniStarterKeymapIcon'
          item._icon_virtual = true
        elseif item.name == 'Edit new buffer' then
          item.name = 'New file'
          item._icon = ''
          item._icon_hl = 'MiniStarterFileIcon'
          item._icon_virtual = true
        elseif item.name == 'Quit Neovim' then
          item.name = 'Quit'
          item._icon = ''
          item._icon_hl = 'MiniStarterQuitIcon'
          item._icon_virtual = true
        else
          item._icon = ''
          item._icon_hl = 'MiniStarterKeymapIcon'
          item._icon_virtual = true
        end
      end
      return actions
    end

    local starter_setup_done = false

    local function setup_starter()
      if starter_setup_done then
        return
      end
      starter_setup_done = true

      local MiniStarter = require('mini.starter')

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
          function(content)
            local header_idx = 1
            for line_i, line in ipairs(content) do
              local is_header_line = false
              for _, unit in ipairs(line) do
                if unit.type == 'header' then
                  is_header_line = true
                  break
                end
              end
              if not is_header_line then
                goto continue
              end

              local raw = starter_header_lines[header_idx]
              if not raw then
                goto continue
              end

              local new_line = {}
              for _, unit in ipairs(line) do
                if unit.type ~= 'header' then
                  table.insert(new_line, unit)
                else
                  local total_chars = vim.fn.strchars(raw)
                  for ci = 0, total_chars - 1 do
                    local s = vim.str_byteindex(raw, ci)
                    local e = vim.str_byteindex(raw, ci + 1)
                    table.insert(new_line, {
                      string = raw:sub(s + 1, e),
                      type = 'header',
                      hl = header_gradient_hl(ci, total_chars),
                    })
                  end
                end
              end
              content[line_i] = new_line
              header_idx = header_idx + 1
              ::continue::
            end
            return content
          end,
          function(content)
            local coords = MiniStarter.content_coords(content, 'item')
            for i = #coords, 1, -1 do
              local l_num, u_num = coords[i].line, coords[i].unit
              local unit = content[l_num][u_num]
              local item = unit and unit.item or nil
              if item and item._icon_virtual and item._icon and item._icon_hl then
                table.insert(content[l_num], u_num, {
                  string = string.format('  %s  ', item._icon),
                  type = 'item_bullet',
                  hl = item._icon_hl,
                  _item = item,
                  _place_cursor = false,
                })
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
          local stats = require('lazy').stats()
          local ms = stats.startuptime
          if ms == 0 and type(stats.times) == 'table' then
            ms = stats.times.LazyDone or stats.times.LazyStart or 0
          end
          return string.format('󰓅  Neovim loaded (%d / %d) plugins in %.2f ms', stats.loaded, stats.count, ms)
        end,
      })
    end

    local function apply_starter_hl()
      local ok_base, base_color = pcall(require, 'wisteria.lib.base_color')
      local wst = (ok_base and base_color and base_color.wst) and base_color.wst or nil

      vim.opt.termguicolors = true
      vim.api.nvim_set_hl(0, 'MiniStarterItemPrefix', { link = 'MiniStarterItem' })
      vim.api.nvim_set_hl(0, 'MiniStarterSectionProjects', { fg = (wst and wst.watarase_blue) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterSectionRecent', { fg = (wst and wst.icho_green) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterSectionKeymaps', { fg = (wst and wst.omugi_gold) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterProjectIcon', { link = 'Directory' })
      vim.api.nvim_set_hl(0, 'MiniStarterKeymapIcon', { fg = '#8491c3', bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterFileIcon', { fg = '#8491c3', bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterQuitIcon', { fg = '#8491c3', bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterItemEmphasis', { bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterItemPath', { fg = '#6b7280', italic = false })
      vim.api.nvim_set_hl(0, 'MiniStarterQuery', { italic = false })
      vim.api.nvim_set_hl(0, 'MiniStarterFooter', { fg = (wst and wst.sky) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterFooterIcon', { fg = (wst and wst.omugi_gold) or nil, bold = true })
      vim.api.nvim_set_hl(0, 'MiniStarterFooterNumber', { fg = (wst and wst.flower_fuji) or nil, bold = true })
    end

    local function repaint_starter_buffer(buf)
      if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= 'ministarter' then
        return
      end

      vim.api.nvim_buf_clear_namespace(buf, starter_icon_ns, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, starter_footer_ns, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, starter_emphasis_ns, 0, -1)
      vim.api.nvim_buf_clear_namespace(buf, starter_path_ns, 0, -1)

      local items = MiniStarter.content_to_items(MiniStarter.get_content(buf))
      for _, item in ipairs(items) do
        if (not item._icon_virtual) and item._icon and item._icon_hl and item._line ~= nil and item._start_col ~= nil then
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
        if line:find('Neovim loaded (', 1, true) and s and e then
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

    if vim.g.mini_starter_requested then
      setup_starter()

      vim.api.nvim_create_autocmd('User', {
        pattern = 'MiniStarterOpened',
        callback = function()
          local MiniStarter = require('mini.starter')
          local buf = vim.api.nvim_get_current_buf()
          local opts = { noremap = true, silent = true, buffer = buf }
          vim.keymap.set('n', 'j', function()
            MiniStarter.update_current_item('next', buf)
          end, opts)
          vim.keymap.set('n', 'k', function()
            MiniStarter.update_current_item('prev', buf)
          end, opts)

          repaint_starter_buffer(buf)
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
          repaint_starter_buffer(buf)
        end,
      })
    end

    if vim.g.mini_starter_requested then
      vim.api.nvim_create_autocmd('User', {
        pattern = 'VeryLazy',
        once = true,
        callback = setup_non_starter,
      })
    else
      setup_non_starter()
    end
  end,
}
