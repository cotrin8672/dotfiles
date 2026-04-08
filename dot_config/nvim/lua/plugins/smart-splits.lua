
return {
  name = "smart-splits.nvim",
  "mrjones2014/smart-splits.nvim",
  opts = {
    default_amount = 3,
    at_edge = "stop",
    wezterm_cli_path = "/mnt/c/Users/gummy/scoop/apps/wezterm-nightly/nightly-20260130/wezterm.exe",
  },
  keys = {
    {
      "<C-h>",
      function()
        require("smart-splits").move_cursor_left()
      end,
      desc = "Move to left split",
      silent = true,
    },
    {
      "<C-j>",
      function()
        require("smart-splits").move_cursor_down()
      end,
      desc = "Move to lower split",
      silent = true,
    },
    {
      "<C-k>",
      function()
        require("smart-splits").move_cursor_up()
      end,
      desc = "Move to upper split",
      silent = true,
    },
    {
      "<C-l>",
      function()
        require("smart-splits").move_cursor_right()
      end,
      desc = "Move to right split",
      silent = true,
    },
  },
  config = function(_, opts)
    require("smart-splits").setup(opts)
  end,
}
