
return {
  name = "mini.icons",
  "nvim-mini/mini.icons",
  lazy = false,
  config = function()
    require("mini.icons").setup()
    MiniIcons.mock_nvim_web_devicons()
  end,
}
