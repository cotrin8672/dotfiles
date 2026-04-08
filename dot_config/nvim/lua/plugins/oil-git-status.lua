
return {
  name = "oil-git-status.nvim",
  "refractalize/oil-git-status.nvim",
  dependencies = {
    {
      name = "oil.nvim",
      "stevearc/oil.nvim",
    },
  },
  event = "VeryLazy",
  config = function()
    require("oil-git-status").setup()
  end,
}
