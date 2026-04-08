
return {
  name = "everforest",
  "neanias/everforest-nvim",
  lazy = false,
  priority = 1000,
  config = function()
    require("everforest").setup({
      background = "hard",
      italics = false,
      transparent_background_level = 2,
    })
    vim.cmd.colorscheme("everforest")

    local colours = require("everforest.colours")
    local palette = colours.generate_palette(require("everforest").config, vim.o.background)
    vim.api.nvim_set_hl(0, "LineNr", { fg = palette.grey0 })
    vim.api.nvim_set_hl(0, "LineNrAbove", { fg = palette.grey0 })
    vim.api.nvim_set_hl(0, "LineNrBelow", { fg = palette.grey0 })
    vim.api.nvim_set_hl(0, "CursorLineNr", { fg = palette.grey0 })
    vim.api.nvim_set_hl(0, "LspInlayHint", { fg = palette.grey0 })
    vim.api.nvim_set_hl(0, "Whitespace", { fg = palette.bg3 })
  end,
}
