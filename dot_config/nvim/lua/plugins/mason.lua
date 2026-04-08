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
    opts = {
      ensure_installed = {
        "lua_ls",
        "nixd",
        "bashls",
        "jsonls",
        "html",
        "cssls",
        "ts_ls",
        "rust_analyzer",
        "taplo",
        "marksman",
      },
      automatic_enable = true,
    },
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
        "rustfmt",
      },
      auto_update = false,
      run_on_start = true,
      start_delay = 0,
    },
  },
}
