local M = {}

function M.refresh_ui()
  vim.schedule(function()
    local ok, lualine = pcall(require, "lualine")
    if ok then
      lualine.refresh()
    end
  end)
end

return M
