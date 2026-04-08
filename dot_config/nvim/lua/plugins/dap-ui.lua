
return {
  name = "nvim-dap-ui",
  "rcarriga/nvim-dap-ui",
  event = "VeryLazy",
  dependencies = {
    {
      name = "nvim-dap",
      "mfussenegger/nvim-dap",
    },
    {
      name = "nvim-nio",
      "nvim-neotest/nvim-nio",
    },
  },
  config = function()
    require("dapui").setup()
  end,
}
