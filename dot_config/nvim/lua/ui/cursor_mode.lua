local M = {}
local initialized = false

local fallback = {
  normal = "#6666CC",
  insert = "#80C28E",
  visual = "#A894D1",
  command = "#D2C7A2",
  replace = "#BA5E5E",
  terminal = "#80C28E",
}

local function hex_to_rgb(hex)
  local s = hex:gsub("#", "")
  if #s ~= 6 then
    return 0, 0, 0
  end
  return tonumber(s:sub(1, 2), 16) or 0, tonumber(s:sub(3, 4), 16) or 0, tonumber(s:sub(5, 6), 16) or 0
end

local function rgb_to_hex(r, g, b)
  return string.format("#%02X%02X%02X", math.max(0, math.min(255, r)), math.max(0, math.min(255, g)), math.max(0, math.min(255, b)))
end

local function mix(hex_a, hex_b, ratio)
  local ar, ag, ab = hex_to_rgb(hex_a)
  local br, bg, bb = hex_to_rgb(hex_b)
  local r = math.floor(ar * (1 - ratio) + br * ratio + 0.5)
  local g = math.floor(ag * (1 - ratio) + bg * ratio + 0.5)
  local b = math.floor(ab * (1 - ratio) + bb * ratio + 0.5)
  return rgb_to_hex(r, g, b)
end

local function get_mode_key()
  local mode = vim.api.nvim_get_mode().mode
  if mode:find("^i") then
    return "insert"
  end
  if mode:find("^[vV]") or mode == "\22" then
    return "visual"
  end
  if mode:find("^c") then
    return "command"
  end
  if mode:find("^[Rr]") then
    return "replace"
  end
  if mode:find("^t") then
    return "terminal"
  end
  return "normal"
end

local function get_submode_color()
  local ok, sm = pcall(require, "nvim-submode")
  if not ok or not sm or type(sm.get_submode_color) ~= "function" then
    return nil
  end

  local color = sm.get_submode_color()
  if type(color) == "string" and color ~= "" then
    return color
  end
  return nil
end

function M.refresh()
  local base_bg = "#272e33"
  local color = get_submode_color() or fallback[get_mode_key()] or fallback.normal
  local line_bg = mix(base_bg, color, 0.35)
  vim.api.nvim_set_hl(0, "CursorLine", { bg = line_bg })
  vim.api.nvim_set_hl(0, "CursorColumn", { bg = line_bg })
end

function M.setup()
  if initialized then
    return
  end
  initialized = true

  local group = vim.api.nvim_create_augroup("CursorModeColor", { clear = true })
  vim.api.nvim_create_autocmd({ "ModeChanged", "WinEnter", "BufEnter", "ColorScheme", "VimEnter" }, {
    group = group,
    callback = function()
      M.refresh()
    end,
  })

  M.refresh()
end

return M
