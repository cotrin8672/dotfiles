-- Run from the repository root: nvim --headless -u NONE -i NONE -l tests/nvim_starter_swap.lua
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/mini.starter")
local spec = require("plugins.mini-starter")
local directory = vim.fn.tempname()
vim.fn.mkdir(directory, "p")
vim.o.directory = directory .. "//"

local function startup()
  spec.config(nil, {
    header = "",
    footer = "",
    items = { { name = "New file", action = "enew", section = "" } },
    content_hooks = {},
  })
  vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })
  local flushed = false
  vim.schedule(function()
    flushed = true
  end)
  assert(vim.wait(1000, function()
    return flushed
  end), "startup callbacks must finish")
end

local ok, err = pcall(function()
  vim.go.swapfile = true
  vim.bo.swapfile = true
  startup()
  assert(vim.bo.filetype == "ministarter", "startup must open the dashboard")
  assert(vim.go.swapfile, "new editing buffers must retain swap protection")
  assert(not vim.bo.swapfile, "restoring the default must not enable dashboard swap")
  assert(vim.fn.swapname(vim.api.nvim_get_current_buf()) == "", "dashboard must have no swap file")

  vim.cmd.enew()
  assert(vim.bo.swapfile, "normal editing buffers must use swap")
  vim.api.nvim_buf_set_name(0, directory .. "/editing.txt")
  vim.bo.swapfile = false
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "file contents" })
  startup()
  assert(vim.bo.filetype ~= "ministarter", "existing content must skip the dashboard")
  assert(vim.go.swapfile and not vim.bo.swapfile, "skipped startup must restore global and local values separately")
end)

vim.bo.swapfile = false
vim.fn.delete(directory, "d")
assert(ok, err)
print("mini.starter swap checks passed")
