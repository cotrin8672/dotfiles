
return {
  name = "nvim-ts-autotag",
  "windwp/nvim-ts-autotag",
  event = { "BufReadPost", "BufNewFile" },
  dependencies = {
    {
      name = "nvim-treesitter",
      "nvim-treesitter/nvim-treesitter",
    },
  },
  config = function()
    require("nvim-ts-autotag").setup({
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
      },
    })
  end,
}
