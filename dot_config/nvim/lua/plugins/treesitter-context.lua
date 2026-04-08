
return {
  name = "nvim-treesitter-context",
  "nvim-treesitter/nvim-treesitter-context",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    {
      name = "nvim-treesitter",
      "nvim-treesitter/nvim-treesitter",
    },
  },
  opts = {
    max_lines = 3,
  },
}
