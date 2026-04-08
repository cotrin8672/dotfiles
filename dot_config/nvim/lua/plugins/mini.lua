
return {
  name = "mini.nvim",
  "nvim-mini/mini.nvim",
  event = "VeryLazy",
  init = function()
    vim.api.nvim_create_autocmd("VimEnter", {
      once = true,
      callback = function()
        if vim.fn.argc() > 0 then
          return
        end
        if vim.bo.filetype ~= "" or vim.api.nvim_buf_get_name(0) ~= "" then
          return
        end

        vim.g.mini_starter_requested = true
        require("lazy").load({ plugins = { "mini.nvim" } })
        require("mini.starter").open()
      end,
    })
  end,
  config = function()
    require("config.mini.ai")()
    require("config.mini.align")()
    require("config.mini.clue")()
    require("config.mini.cursorword")()
    require("config.mini.hipatterns")()
    require("config.mini.indentscope")()
    require("config.mini.misc")()
    require("config.mini.move")()
    require("config.mini.operators")()
    require("config.mini.pick")()
    require("config.mini.sessions")()
    require("config.mini.starter")()
    require("config.mini.surround")()
    require("config.mini.visits")()
  end,
}
