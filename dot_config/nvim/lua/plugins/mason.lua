return {
  {
    name = "mason.nvim",
    "mason-org/mason.nvim",
    lazy = false,
    opts = {
      PATH = "prepend",
    },
  },
  {
    name = "mason-lspconfig.nvim",
    "mason-org/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
      "mason.nvim",
      "neovim/nvim-lspconfig",
    },
    opts = function()
      local ensure_installed = {
        "lua_ls",
        "bashls",
        "jsonls",
        "html",
        "cssls",
        "ts_ls",
        "rust_analyzer",
        "taplo",
        "marksman",
      }

      if vim.fn.has("win32") == 0 then
        table.insert(ensure_installed, "nixd")
      end

      return {
        ensure_installed = ensure_installed,
        automatic_enable = true,
      }
    end,
  },
  {
    name = "mason-tool-installer.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = {
      "mason.nvim",
    },
    opts = {
      ensure_installed = {
        "jdtls",
        "kotlin-lsp",
        "google-java-format",
        "ktfmt",
        "prettier",
        "stylua",
        "alejandra",
        "shfmt",
      },
      auto_update = false,
      run_on_start = true,
      start_delay = 0,
    },
  },
}
