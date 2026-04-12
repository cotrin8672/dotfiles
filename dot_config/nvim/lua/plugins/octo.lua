return {
  {
    name = "octo.nvim",
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
      "plenary.nvim",
      "folke/snacks.nvim",
    },
    opts = {
      picker = "snacks",
      enable_builtin = true,
    },
    config = function(_, opts)
      require("octo").setup(opts)
    end,
  },
}
