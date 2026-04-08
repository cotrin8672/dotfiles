
return {
  name = "nvim-ts-context-commentstring",
  "JoosepAlviste/nvim-ts-context-commentstring",
  event = "VeryLazy",
  config = function()
    require("ts_context_commentstring").setup({
      enable_autocmd = false,
    })
  end,
}
