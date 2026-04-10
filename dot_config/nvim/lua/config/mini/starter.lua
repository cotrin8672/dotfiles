return function()
  local MiniStarter = require("mini.starter")
  local SECTION_SESSIONS = "󰙰  Sessions"
  local SECTION_RECENT = "󰈔  Recent files (current directory)"
  local SECTION_KEYMAPS = "  Keymaps"

  local starter_icon_ns = vim.api.nvim_create_namespace("starter_icon_colors")
  local starter_footer_ns = vim.api.nvim_create_namespace("starter_footer_colors")
  local starter_emphasis_ns = vim.api.nvim_create_namespace("starter_emphasis_colors")
  local starter_path_ns = vim.api.nvim_create_namespace("starter_path_colors")
  local header_hl_cache = {}
  local starter_header_lines = {
    "███╗   ██╗ ███████╗  ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗",
    "████╗  ██║ ██╔════╝ ██╔═══██╗ ██║   ██║ ██║ ████╗ ████║",
    "██╔██╗ ██║ █████╗   ██║   ██║ ██║   ██║ ██║ ██╔████╔██║",
    "██║╚██╗██║ ██╔══╝   ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║",
    "██║ ╚████║ ███████╗ ╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║",
    "╚═╝  ╚═══╝ ╚══════╝  ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝",
  }

  local function header_gradient_hl(char_idx, total_chars)
    local t = (total_chars <= 1) and 0 or (char_idx / (total_chars - 1))
    local r = math.floor(19 + (113 - 19) * t + 0.5)
    local g = math.floor(78 + (178 - 78) * t + 0.5)
    local b = math.floor(94 + (128 - 94) * t + 0.5)
    local hl = string.format("MiniStarterHeaderGrad_%02x%02x%02x", r, g, b)
    if not header_hl_cache[hl] then
      header_hl_cache[hl] = true
      vim.api.nvim_set_hl(0, hl, { fg = string.format("#%02x%02x%02x", r, g, b), bold = true })
    end
    return hl
  end

  local function decode_session_root(session_name)
    if not vim.startswith(session_name, "git-") then
      return nil
    end

    local raw = session_name:gsub("^git%-", "")
    raw = raw:gsub("%%", "/")
    if not vim.startswith(raw, "/") then
      raw = "/" .. raw
    end
    return raw
  end

  local function section_sessions(limit)
    limit = limit or 8

    return function()
      local icons = require("mini.icons")
      if _G.MiniSessions == nil then
        local icon, icon_hl = icons.get("default", "directory")
        return {
          {
            name = [["mini.sessions" is not set up]],
            action = "",
            section = SECTION_SESSIONS,
            _icon = icon,
            _icon_hl = icon_hl,
            _icon_virtual = true,
          },
        }
      end

      local items = {}
      for session_name, session in pairs(_G.MiniSessions.detected or {}) do
        if session.type == "global" then
          local root = decode_session_root(session_name)
          if root ~= nil then
            local dir_name = vim.fn.fnamemodify(root, ":t")
            table.insert(items, {
              name = dir_name,
              section = SECTION_SESSIONS,
              _icon = "󰙰",
              _icon_hl = "MiniStarterProjectIcon",
              _icon_virtual = true,
              _emph_text = dir_name,
              _session = session,
              action = function()
                _G.MiniSessions.read(session_name, { force = true, verbose = false })
              end,
            })
          end
        end
      end

      table.sort(items, function(a, b)
        return (a._session.modify_time or 0) > (b._session.modify_time or 0)
      end)

      if #items == 0 then
        local icon, icon_hl = icons.get("default", "directory")
        return {
          {
            name = "No sessions yet",
            action = "",
            section = SECTION_SESSIONS,
            _icon = icon,
            _icon_hl = icon_hl,
            _icon_virtual = true,
          },
        }
      end

      return vim.tbl_map(function(item)
        item._session = nil
        return item
      end, vim.list_slice(items, 1, limit))
    end
  end

  local function section_recent_files(limit)
    limit = limit or 8

    return function()
      local cwd = vim.fn.getcwd()
      local icons = require("mini.icons")
      local sep = package.config:sub(1, 1)
      local cwd_prefix = cwd .. sep
      local items = {}

      for _, f in ipairs(vim.v.oldfiles or {}) do
        if vim.fn.filereadable(f) == 1 and vim.startswith(f, cwd_prefix) then
          local basename = vim.fn.fnamemodify(f, ":t")
          local icon, icon_hl = icons.get("file", f)

          table.insert(items, {
            name = basename,
            section = SECTION_RECENT,
            _icon = icon,
            _icon_hl = icon_hl,
            _icon_virtual = true,
            _emph_text = basename,
            action = function()
              vim.cmd("edit " .. vim.fn.fnameescape(f))
            end,
          })
          if #items >= limit then
            break
          end
        end
      end

      if #items == 0 then
        local icon, icon_hl = icons.get("default", "file")
        return {
          {
            name = "No recent files in current directory",
            action = "",
            section = SECTION_RECENT,
            _icon = icon,
            _icon_hl = icon_hl,
            _icon_virtual = true,
          },
        }
      end

      return items
    end
  end

  local function section_builtin_actions_with_icon()
    local icons = require("mini.icons")
    local actions = {
      { name = "Lazy", action = "Lazy", section = "Builtin actions" },
      { name = "Oil", action = "Oil --float", section = "Builtin actions" },
      { name = "Edit new buffer", action = "enew", section = "Builtin actions" },
      { name = "Quit Neovim", action = "qall", section = "Builtin actions" },
    }

    for _, item in ipairs(actions) do
      item.section = SECTION_KEYMAPS
      if item.name == "Lazy" then
        item._icon, item._icon_hl = icons.get("filetype", "lazy")
      elseif item.name == "Oil" then
        item._icon, item._icon_hl = icons.get("filetype", "oil")
      elseif item.name == "Edit new buffer" then
        item.name = "New file"
        item._icon = ""
        item._icon_hl = "MiniStarterFileIcon"
      elseif item.name == "Quit Neovim" then
        item.name = "Quit"
        item._icon = ""
        item._icon_hl = "MiniStarterQuitIcon"
      else
        item._icon = "*"
        item._icon_hl = "MiniStarterKeymapIcon"
      end
      item._icon_virtual = true
    end

    return actions
  end

  MiniStarter.setup({
    evaluate_single = true,
    header = table.concat(starter_header_lines, "\n"),
    items = {
      section_sessions(10),
      section_recent_files(8),
      section_builtin_actions_with_icon,
    },
    content_hooks = {
      function(content)
        for _, line in ipairs(content) do
          for _, unit in ipairs(line) do
            if unit.type == "section" then
              if unit.string:find("Sessions", 1, true) then
                unit.hl = "MiniStarterSectionProjects"
              elseif unit.string:find("Recent files", 1, true) then
                unit.hl = "MiniStarterSectionRecent"
              elseif unit.string:find("Keymaps", 1, true) then
                unit.hl = "MiniStarterSectionKeymaps"
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
            if unit.type == "header" then
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
            if unit.type ~= "header" then
              table.insert(new_line, unit)
            else
              local total_chars = vim.fn.strchars(raw)
              for ci = 0, total_chars - 1 do
                local s = vim.str_byteindex(raw, ci)
                local e = vim.str_byteindex(raw, ci + 1)
                table.insert(new_line, {
                  string = raw:sub(s + 1, e),
                  type = "header",
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
        local coords = MiniStarter.content_coords(content, "item")
        for i = #coords, 1, -1 do
          local l_num, u_num = coords[i].line, coords[i].unit
          local unit = content[l_num][u_num]
          local item = unit and unit.item or nil
          if item and item._icon_virtual and item._icon and item._icon_hl then
            table.insert(content[l_num], u_num, {
              string = string.format("  %s  ", item._icon),
              type = "item_bullet",
              hl = item._icon_hl,
              _item = item,
              _place_cursor = false,
            })
          end
        end
        return content
      end,
      MiniStarter.gen_hook.aligning("center", "center"),
      function(content)
        local columns = vim.o.columns
        for _, line in ipairs(content) do
          local has_footer = false
          local has_header = false
          local line_text = ""
          for _, unit in ipairs(line) do
            line_text = line_text .. (unit.string or "")
            if unit.type == "footer" then
              has_footer = true
            elseif unit.type == "header" then
              has_header = true
            end
          end

          if has_header or has_footer then
            if line[1] and line[1].string then
              line[1].string = line[1].string:gsub("^%s+", "")
            end
            line_text = ""
            for _, unit in ipairs(line) do
              line_text = line_text .. (unit.string or "")
            end
            local width = vim.fn.strdisplaywidth(line_text)
            local pad = math.max(math.floor((columns - width) / 2), 0)
            if pad > 0 and line[1] then
              line[1].string = string.rep(" ", pad) .. line[1].string
            end
          end
        end
        return content
      end,
    },
    footer = function()
      local stats = require("lazy").stats()
      local ms = stats.startuptime
      if ms == 0 and type(stats.times) == "table" then
        ms = stats.times.LazyDone or stats.times.LazyStart or 0
      end
      return string.format("Loaded %d / %d plugins in %.2f ms", stats.loaded, stats.count, ms)
    end,
  })

  local function apply_starter_hl()
    vim.opt.termguicolors = true
    vim.api.nvim_set_hl(0, "MiniStarterItemPrefix", { link = "MiniStarterItem" })
    vim.api.nvim_set_hl(0, "MiniStarterSectionProjects", { fg = "#7fbbb3", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterSectionRecent", { fg = "#a7c080", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterSectionKeymaps", { fg = "#dbbc7f", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterProjectIcon", { link = "Directory" })
    vim.api.nvim_set_hl(0, "MiniStarterKeymapIcon", { fg = "#7fbbb3", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterFileIcon", { fg = "#7fbbb3", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterQuitIcon", { fg = "#e67e80", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterItemEmphasis", { bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterItemPath", { fg = "#859289", italic = false })
    vim.api.nvim_set_hl(0, "MiniStarterQuery", { italic = false })
    vim.api.nvim_set_hl(0, "MiniStarterFooter", { fg = "#83c092", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterFooterIcon", { fg = "#dbbc7f", bold = true })
    vim.api.nvim_set_hl(0, "MiniStarterFooterNumber", { fg = "#d699b6", bold = true })
  end

  local function repaint_starter_buffer(buf)
    if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].filetype ~= "ministarter" then
      return
    end

    vim.api.nvim_buf_clear_namespace(buf, starter_icon_ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, starter_footer_ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, starter_emphasis_ns, 0, -1)
    vim.api.nvim_buf_clear_namespace(buf, starter_path_ns, 0, -1)

    local items = MiniStarter.content_to_items(MiniStarter.get_content(buf))
    for _, item in ipairs(items) do
      if item._emph_text and item._line ~= nil and item._start_col ~= nil and item.name then
        local ss = item.name:find(item._emph_text, 1, true)
        if ss then
          local start_col = item._start_col + (ss - 1)
          local end_col = start_col + vim.fn.strchars(item._emph_text)
          vim.api.nvim_buf_add_highlight(buf, starter_emphasis_ns, "MiniStarterItemEmphasis", item._line, start_col, end_col)
        end
      end

      if item._path_text and item._line ~= nil and item._start_col ~= nil and item.name then
        local ss = item.name:find(item._path_text, 1, true)
        if ss then
          local start_col = item._start_col + (ss - 1)
          local end_col = start_col + vim.fn.strchars(item._path_text)
          vim.api.nvim_buf_add_highlight(buf, starter_path_ns, "MiniStarterItemPath", item._line, start_col, end_col)
        end
      end
    end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, line in ipairs(lines) do
      local s, e = line:find("%d+%.%d+ ms")
      if line:find("Loaded ", 1, true) and s and e then
        vim.api.nvim_buf_add_highlight(buf, starter_footer_ns, "MiniStarterFooterNumber", i - 1, s - 1, e)
      end
    end
  end

  apply_starter_hl()
  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = apply_starter_hl,
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "MiniStarterOpened",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      local opts = { noremap = true, silent = true, buffer = buf }
      vim.keymap.set("n", "j", function()
        MiniStarter.update_current_item("next", buf)
      end, opts)
      vim.keymap.set("n", "k", function()
        MiniStarter.update_current_item("prev", buf)
      end, opts)

      repaint_starter_buffer(buf)
      vim.schedule(function()
        repaint_starter_buffer(buf)
      end)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "VimResized" }, {
    callback = function(args)
      local buf = args.buf or vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "ministarter" then
        repaint_starter_buffer(buf)
      end
    end,
  })
end
