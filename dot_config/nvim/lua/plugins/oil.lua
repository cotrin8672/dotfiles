local float = require("shared.float")

return {
  name = "oil.nvim",
  "stevearc/oil.nvim",
  cmd = "Oil",
  keys = {
    { "-", "<cmd>Oil<cr>", desc = "Oil: Parent dir" },
    { "<leader>e", "<cmd>Oil --float<cr>", desc = "Oil: Float" },
    { "<leader>O", "<cmd>Oil<cr>", desc = "Oil: CWD" },
  },
  opts = {
    default_file_explorer = true,
    float = {
      max_width = 0.62,
      max_height = 0.7,
      win_options = {
        winblend = float.blend,
      },
    },
    win_options = {
      signcolumn = "yes:2",
    },
    view_options = {
      show_hidden = true,
    },
    keymaps = {
      ["<CR>"] = "actions.select",
      ["<C-s>"] = "actions.select_split",
      ["<C-v>"] = "actions.select_vsplit",
      ["<C-t>"] = "actions.select_tab",
      ["<Esc>"] = "actions.close",
      ["-"] = "actions.parent",
      ["g."] = "actions.toggle_hidden",
    },
  },
  dependencies = {
    {
      name = "nvim-web-devicons",
      "nvim-tree/nvim-web-devicons",
    },
  },
}
