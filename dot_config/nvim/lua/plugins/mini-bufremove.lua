
return {
  name = "mini.bufremove",
  "nvim-mini/mini.bufremove",
  event = "VeryLazy",
  config = function()
    require("mini.bufremove").setup()
  end,
}
