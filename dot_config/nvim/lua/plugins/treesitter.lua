
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
    local treesitter = require("nvim-treesitter")

    treesitter.setup({
      ensure_installed = parsers,
      auto_install = true,
      sync_install = false,
    })

    local group = vim.api.nvim_create_augroup("NvimTreesitter", { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(event)
        local ok = pcall(vim.treesitter.start, event.buf)
        if not ok then
          return
        end

        vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
      end,
    })
  end,
}
