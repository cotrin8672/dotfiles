return function()
  local sessions = require("mini.sessions")
  local managed_session_name = nil

  local function git_root(path)
    local dot_git = vim.fs.find(".git", {
      path = path or vim.fn.getcwd(),
      upward = true,
      limit = 1,
    })[1]

    return dot_git and vim.fs.dirname(dot_git) or nil
  end

  local function session_name(root)
    local normalized = vim.fs.normalize(root)
    return "git-" .. normalized:gsub("[:/\\]+", "%%")
  end

  local function ensure_repo_session()
    local root = git_root()
    if not root then
      return
    end

    local name = session_name(root)
    if sessions.detected[name] ~= nil then
      sessions.read(name, { force = true, verbose = false })
      managed_session_name = name
      return
    end

    sessions.write(name, { force = true, verbose = false })
    managed_session_name = name
  end

  local function should_autoread()
    if vim.fn.argc() > 0 then
      return false
    end

    return vim.api.nvim_buf_get_name(0) == "" and vim.bo.filetype == ""
  end

  sessions.setup({
    autoread = false,
    autowrite = true,
    file = "",
    verbose = {
      read = false,
      write = false,
      delete = true,
    },
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    callback = function()
      if not should_autoread() then
        return
      end

      ensure_repo_session()
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function()
      if managed_session_name == nil then
        if vim.g.mini_starter_requested ~= true then
          return
        end

        local root = git_root()
        if not root then
          return
        end

        managed_session_name = session_name(root)
      end

      sessions.write(managed_session_name, { force = true, verbose = false })
    end,
  })
end
