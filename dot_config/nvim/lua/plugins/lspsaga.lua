
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
  },
  opts = {
    lightbulb = {
      enable = false,
    },
  },
}
