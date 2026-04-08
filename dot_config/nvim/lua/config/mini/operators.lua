return function()
  require("mini.operators").setup({
    evaluate = { prefix = "g=" },
    exchange = { prefix = "gx" },
    multiply = { prefix = "gm" },
    replace = { prefix = "gR" },
    sort = { prefix = "gs" },
  })
end
