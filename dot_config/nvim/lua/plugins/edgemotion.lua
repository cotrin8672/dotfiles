
return {
  name = "vim-edgemotion",
  "haya14busa/vim-edgemotion",
  keys = {
    { "]j", mode = "n" },
    { "[k", mode = "n" },
  },
  config = function()
    local map = vim.keymap.set
    local key_opts = { remap = true, silent = true }
    map("n", "]j", "<Plug>(edgemotion-j)", key_opts)
    map("n", "[k", "<Plug>(edgemotion-k)", key_opts)
  end,
}
