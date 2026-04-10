
local parsers = {
  "bash",
  "css",
  "html",
  "java",
  "javascript",
  "json",
  "kotlin",
  "lua",
  "markdown",
  "markdown_inline",
  "nix",
  "rust",
  "toml",
  "tsx",
  "typescript",
  "zsh",
}

return {
  name = "nvim-treesitter",
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  priority = 1000,
  build = ":TSUpdate",
  config = function()
    local install = require("nvim-treesitter.install")
    local treesitter = require("nvim-treesitter")

    install.compilers = {
      "zig",
      "clang",
      "gcc",
      "cc",
    }

    treesitter.setup({
      ensure_installed = parsers,
      auto_install = true,
      sync_install = false,
    })

    local group = vim.api.nvim_create_augroup("NvimTreesitter", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(event)
        pcall(vim.treesitter.start, event.buf)
      end,
    })
  end,
}
