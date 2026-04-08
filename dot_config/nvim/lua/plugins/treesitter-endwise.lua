
return {
  name = "nvim-treesitter-endwise",
  "RRethy/nvim-treesitter-endwise",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    {
      name = "nvim-treesitter",
      "nvim-treesitter/nvim-treesitter",
    },
  },
}
