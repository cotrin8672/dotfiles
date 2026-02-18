local wezterm = require 'wezterm'

local M = {}

local function urldecode(value)
  return (value:gsub('%%(%x%x)', function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

local function normalize_windows_path(path)
  if not path or path == '' then
    return ''
  end
  if path:match('^//') then
    path = '\\\\' .. path:gsub('^//', '')
  end
  if path:match('^%a:[/\\]') then
    path = path:gsub('/', '\\')
  end
  return path
end

local function display_path_linux_style(path, wezterm)
  if not path or path == '' then
    return ''
  end
  local p = path:gsub('\\', '/')
  p = p:gsub('^/(%a:/)', '%1')
  local home = wezterm.home_dir or os.getenv('USERPROFILE') or ''
  if home ~= '' then
    local home_norm = home:gsub('\\', '/')
    if p:sub(1, #home_norm) == home_norm then
      local rest = p:sub(#home_norm + 1)
      if rest == '' then
        p = '~'
      elseif rest:sub(1, 1) == '/' then
        p = '~' .. rest
      else
        p = '~/' .. rest
      end
    end
  end
  return p
end

local function cwd_path(pane, wezterm)
  local uri = pane:get_current_working_dir()
  if not uri then
    return ''
  end
  local path
  if type(uri) == 'userdata' and uri.file_path then
    path = uri.file_path
  elseif type(uri) == 'string' then
    if wezterm.uri_to_path then
      local ok, p = pcall(wezterm.uri_to_path, uri)
      path = ok and p or uri
    else
      if uri:match('^file:') then
        path = uri:gsub('^file:///', ''):gsub('^file://', '//')
        path = urldecode(path)
      else
        path = uri
      end
    end
  else
    path = tostring(uri)
  end
  return display_path_linux_style(normalize_windows_path(path), wezterm)
end

function M.setup()
  wezterm.on('update-right-status', function(window, _pane)
    local leader = window:leader_is_active() and 'LEADER' or ''
    window:set_right_status(leader)
  end)
end

return M
