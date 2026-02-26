return {
  'sirasagi62/nvim-submode',
  event = 'VeryLazy',
  config = function()
    local sm = require('nvim-submode')
    local hint_ns = vim.api.nvim_create_namespace('window_submode_hint')
    local hint_buf = nil
    local hint_win = nil

    local function close_window_hint()
      if hint_win and vim.api.nvim_win_is_valid(hint_win) then
        vim.api.nvim_win_close(hint_win, true)
      end
      hint_win = nil
      hint_buf = nil
    end

    local function open_window_hint()
      close_window_hint()

      local lines = {
        ' h │ Focus left',
        ' j │ Focus down',
        ' k │ Focus up',
        ' l │ Focus right',
        ' s │ Split (horizontal)',
        ' v │ Split (vertical)',
        ' + │ Increase height',
        ' - │ Decrease height',
        ' > │ Increase width',
        ' < │ Decrease width',
        ' x │ Close window',
        ' q │ Exit WINDOW mode',
      }

      hint_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[hint_buf].buftype = 'nofile'
      vim.bo[hint_buf].bufhidden = 'wipe'
      vim.bo[hint_buf].swapfile = false
      vim.bo[hint_buf].modifiable = true
      vim.api.nvim_buf_set_lines(hint_buf, 0, -1, false, lines)
      for i = 1, #lines do
        vim.api.nvim_buf_add_highlight(hint_buf, hint_ns, 'MiniClueNextKey', i - 1, 1, 2)
        vim.api.nvim_buf_add_highlight(hint_buf, hint_ns, 'MiniClueSeparator', i - 1, 3, 6)
      end
      vim.bo[hint_buf].modifiable = false

      local width = 34
      local height = #lines
      local col = math.max(vim.o.columns - width - 2, 0)
      hint_win = vim.api.nvim_open_win(hint_buf, false, {
        relative = 'editor',
        row = 3,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = ' WINDOW Mode ',
        title_pos = 'center',
      })
    end

    local function refresh_lualine()
      local ok_cursor, cursor_mode = pcall(require, 'ui.cursor_mode')
      if ok_cursor and type(cursor_mode.refresh) == 'function' then
        cursor_mode.refresh()
      end
      vim.schedule(function()
        local ok, lualine = pcall(require, 'lualine')
        if ok then
          lualine.refresh()
        end
      end)
    end

    local submode_color = '#1E50A2' -- 瑠璃色

    local window_sm = sm.build_submode({
      name = 'WINDOW',
      display_name = 'WINDOW',
      color = submode_color,
      timeoutlen = vim.o.timeoutlen,
      after_enter = function()
        refresh_lualine()
        open_window_hint()
      end,
      after_leave = function()
        refresh_lualine()
        close_window_hint()
      end,
    }, {
      { 'h', '<C-w>h' },
      { 'j', '<C-w>j' },
      { 'k', '<C-w>k' },
      { 'l', '<C-w>l' },
      { 's', '<C-w>s' },
      { 'v', '<C-w>v' },
      { '+', '<C-w>+' },
      { '-', '<C-w>-' },
      { '>', '<C-w>>' },
      { '<', '<C-w><' },
      { 'x', '<C-w>c' },
      { 'q', function()
        return '', sm.EXIT_SUBMODE
      end },
    })

    vim.keymap.set('n', '<leader>w', function()
      sm.enable(window_sm)
    end, { desc = 'Window submode' })
  end,
}
