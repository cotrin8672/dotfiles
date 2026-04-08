
return {
  name = "satellite.nvim",
  "lewis6991/satellite.nvim",
  event = "VeryLazy",
  opts = {
    current_only = false,
    winblend = 0,
    zindex = 40,
    excluded_filetypes = {
      "prompt",
      "TelescopePrompt",
      "neo-tree",
      "oil",
    },
    handlers = {
      search = { enable = true },
      diagnostic = { enable = true },
      gitsigns = { enable = false },
      cursor = { enable = false },
    },
  },
}
