return {
  'shellRaining/hlchunk.nvim',
  event = { 'BufReadPost', 'BufNewFile' },
  config = function()
    local ts = require('hlchunk.utils.ts_node_type')
    local function hl_fg(names)
      if type(names) == 'string' then
        names = { names }
      end
      for _, name in ipairs(names) do
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
        if ok and hl and hl.fg then
          return string.format('#%06x', hl.fg)
        end
      end
      return nil
    end
    local has_wisteria, wisteria = pcall(require, 'wisteria.lib.base_color')
    local wst = has_wisteria and wisteria.wst or nil
    local chunk_fg_1 = (wst and wst.gray) or hl_fg({ 'IblScope', 'NonText', 'LineNr', 'Comment' })
    local chunk_fg_2 = (wst and wst.light_gray) or hl_fg({ 'IblScope', 'NonText', 'LineNr', 'Comment' })
    ts.tsx = {
      'jsx_element',
      'jsx_fragment',
      'jsx_self_closing_element',
      'function_declaration',
      'arrow_function',
      'class_declaration',
      'method_definition',
      '^if',
      '^for',
      '^while',
      'switch_statement',
      'try_statement',
      'catch_clause',
    }
    ts.typescript = ts.typescript or ts.tsx
    require('hlchunk').setup({
      indent = {
        enable = true,
        chars = {
          '│',
        },
      },
      chunk = {
        enable = true,
        priority = 50,
        notify = true,
        style = {
          { fg = chunk_fg_1 },
          { fg = chunk_fg_2 },
        },
        use_treesitter = true,
        chars = {
          horizontal_line = '─',
          vertical_line = '│',
          left_top = '╭',
          left_bottom = '╰',
          right_arrow = '>',
        },
        textobject = '',
        max_file_size = 1024 * 1024,
        error_sign = true,
        duration = 200,
        delay = 50,
      },
      line_num = {
        enable = false,
      },
      blank = {
        enable = false,
      },
    })
  end,
}
