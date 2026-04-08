local M = {}

local group = vim.api.nvim_create_augroup("JavaKotlinPackage", { clear = true })

local function infer_package_name(path)
  local normalized = path:gsub("\\", "/")
  local package_path = normalized:match("/src/main/java/(.+)/[^/]+$")
    or normalized:match("/src/main/kotlin/(.+)/[^/]+$")
    or normalized:match("/src/test/java/(.+)/[^/]+$")
    or normalized:match("/src/test/kotlin/(.+)/[^/]+$")

  if not package_path then
    return nil
  end

  return package_path:gsub("/", ".")
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = group,
    pattern = { "*.java", "*.kt" },
    callback = function(event)
      if vim.b[event.buf].java_kotlin_package_checked then
        return
      end
      vim.b[event.buf].java_kotlin_package_checked = true

      local package_name = infer_package_name(event.match)
      if not package_name then
        return
      end

      local lines = vim.api.nvim_buf_get_lines(event.buf, 0, -1, false)
      if lines[1] and lines[1]:match("^package%s+") then
        return
      end

      if vim.iter(lines):any(function(line)
        return line:match("%S") ~= nil
      end) then
        return
      end

      vim.api.nvim_buf_set_lines(event.buf, 0, -1, false, {
        ("package %s"):format(package_name),
        "",
      })
    end,
  })
end

return M
