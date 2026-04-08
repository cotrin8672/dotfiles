
return {
  name = "nvim-submode",
  "sirasagi62/nvim-submode",
  event = "VeryLazy",
  config = function()
    local sm = require("nvim-submode")

    require("config.submode.window")(sm)
    require("config.submode.debug")(sm)
  end,
}
