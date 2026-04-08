
return {
  name = "lspsaga.nvim",
  "nvimdev/lspsaga.nvim",
  event = "LspAttach",
  keys = {
    {
      "<leader>ca",
      "<cmd>Lspsaga code_action<cr>",
      mode = "n",
      desc = "LSP Code Action",
    },
  },
  dependencies = {
    {
      name = "nvim-treesitter",
      "nvim-treesitter/nvim-treesitter",
    },
    {
      name = "nvim-web-devicons",
      "nvim-tree/nvim-web-devicons",
    },
  },
  opts = {
    lightbulb = {
      enable = false,
    },
  },
}
