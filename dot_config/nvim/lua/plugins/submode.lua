return {
  'sirasagi62/nvim-submode',
  event = 'VeryLazy',
  config = function()
    local sm = require('nvim-submode')
    local hint_ns = vim.api.nvim_create_namespace('window_submode_hint')
    local lsp_hint_ns = vim.api.nvim_create_namespace('lsp_submode_hint')
    local hint_buf = nil
    local hint_win = nil
    local lsp_hint_buf = nil
    local lsp_hint_win = nil

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

    local function close_lsp_hint()
      if lsp_hint_win and vim.api.nvim_win_is_valid(lsp_hint_win) then
        vim.api.nvim_win_close(lsp_hint_win, true)
      end
      lsp_hint_win = nil
      lsp_hint_buf = nil
    end

    local function open_lsp_hint()
      close_lsp_hint()

      local lines = {
        ' r   │ Next reference',
        ' R   │ Prev reference',
        ' d   │ Next diagnostic',
        ' D   │ Prev diagnostic',
        ' a   │ Open code actions',
        ' 1-9 │ Apply code action by number',
        ' q   │ Exit LSP mode',
      }

      lsp_hint_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[lsp_hint_buf].buftype = 'nofile'
      vim.bo[lsp_hint_buf].bufhidden = 'wipe'
      vim.bo[lsp_hint_buf].swapfile = false
      vim.bo[lsp_hint_buf].modifiable = true
      vim.api.nvim_buf_set_lines(lsp_hint_buf, 0, -1, false, lines)
      for i = 1, #lines do
        vim.api.nvim_buf_add_highlight(lsp_hint_buf, lsp_hint_ns, 'MiniClueNextKey', i - 1, 1, 2)
        vim.api.nvim_buf_add_highlight(lsp_hint_buf, lsp_hint_ns, 'MiniClueSeparator', i - 1, 3, 6)
      end
      vim.bo[lsp_hint_buf].modifiable = false
      local width = 40
      local height = #lines
      local col = math.max(vim.o.columns - width - 2, 0)
      lsp_hint_win = vim.api.nvim_open_win(lsp_hint_buf, false, {
        relative = 'editor',
        row = 3,
        col = col,
        width = width,
        height = height,
        style = 'minimal',
        border = 'rounded',
        title = ' LSP Mode ',
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
    local function apply_lspsaga_code_action(selected)
      local ok, ca = pcall(require, 'lspsaga.codeaction')
      if not (ok and ca and ca.action_winid and vim.api.nvim_win_is_valid(ca.action_winid)) then
        vim.cmd('Lspsaga code_action')
        return
      end

      vim.api.nvim_win_call(ca.action_winid, function()
        if selected then
          vim.cmd('normal ' .. tostring(selected))
        else
          vim.cmd([[normal \<CR>]])
        end
      end)
    end

    local function open_lsp_trouble(mode, direction)
      local close_cmd = mode == 'references' and 'Trouble lsp_submode_diagnostics close'
        or 'Trouble lsp_submode_references close'
      local open_cmd = mode == 'references' and 'Trouble lsp_submode_references open focus=false'
        or 'Trouble lsp_submode_diagnostics open focus=false'

      pcall(vim.cmd, close_cmd)
      vim.cmd(open_cmd)
      vim.cmd('Trouble ' .. direction .. ' jump=true skip_groups=true')
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

    local lsp_sm = sm.build_submode({
      name = 'LSP',
      display_name = 'LSP',
      color = '#C0C6C9',
      timeoutlen = vim.o.timeoutlen,
      is_count_enable = false,
      after_enter = function()
        open_lsp_hint()
        refresh_lualine()
      end,
      after_leave = function()
        pcall(vim.cmd, 'Trouble lsp_submode_diagnostics close')
        pcall(vim.cmd, 'Trouble lsp_submode_references close')
        pcall(function()
          require('lspsaga.codeaction'):close_action_window()
        end)
        close_lsp_hint()
        refresh_lualine()
      end,
    }, {
      {
        'r',
        function()
          open_lsp_trouble('references', 'next')
        end,
      },
      {
        'R',
        function()
          open_lsp_trouble('references', 'prev')
        end,
      },
      {
        'd',
        function()
          open_lsp_trouble('diagnostics', 'next')
        end,
      },
      {
        'D',
        function()
          open_lsp_trouble('diagnostics', 'prev')
        end,
      },
      {
        'a',
        '<Cmd>Lspsaga code_action<CR>',
      },
      { '1', function() apply_lspsaga_code_action(1) return '' end },
      { '2', function() apply_lspsaga_code_action(2) return '' end },
      { '3', function() apply_lspsaga_code_action(3) return '' end },
      { '4', function() apply_lspsaga_code_action(4) return '' end },
      { '5', function() apply_lspsaga_code_action(5) return '' end },
      { '6', function() apply_lspsaga_code_action(6) return '' end },
      { '7', function() apply_lspsaga_code_action(7) return '' end },
      { '8', function() apply_lspsaga_code_action(8) return '' end },
      { '9', function() apply_lspsaga_code_action(9) return '' end },
      { 'j', 'j' },
      { 'k', 'k' },
      { 'h', 'h' },
      { 'l', 'l' },
      {
        '<CR>',
        function()
          apply_lspsaga_code_action(nil)
          return ''
        end,
      },
      { '<Tab>', '<Cmd>BufferNext<CR>' },
      { '<S-Tab>', '<Cmd>BufferPrevious<CR>' },
      {
        'q',
        function()
          return '', sm.EXIT_SUBMODE
        end,
      },
    })

    vim.keymap.set('n', '<leader>l', function()
      sm.enable(lsp_sm)
    end, { desc = 'LSP submode' })
  end,
}
