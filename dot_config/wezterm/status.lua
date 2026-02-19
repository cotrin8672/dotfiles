local wezterm = require 'wezterm'

local M = {}

function M.setup()
  wezterm.on('update-right-status', function(window, _pane)
    local leader = window:leader_is_active() and 'LEADER' or ''
    window:set_right_status(leader)
  end)
end

return M
