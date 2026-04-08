return function()
  local miniclue = require("mini.clue")

  miniclue.setup({
    triggers = {
      { mode = "n", keys = "<Leader>" },
      { mode = "x", keys = "<Leader>" },
      { mode = "n", keys = "g" },
      { mode = "x", keys = "g" },
      { mode = "n", keys = "[" },
      { mode = "n", keys = "]" },
      { mode = "n", keys = "z" },
      { mode = "x", keys = "z" },
      { mode = "n", keys = "<C-w>" },
    },
    clues = {
      { mode = "n", keys = "<Leader>a", desc = "+align" },
      { mode = "n", keys = "<Leader>e", desc = "Oil float" },
      { mode = "n", keys = "<Leader>O", desc = "Oil cwd" },
      { mode = "n", keys = "<Leader>p", desc = "+pick" },
      { mode = "n", keys = "<Leader>pb", desc = "Pick git branches" },
      { mode = "n", keys = "<Leader>pd", desc = "Pick diagnostics" },
      { mode = "n", keys = "<Leader>pf", desc = "Pick git files" },
      { mode = "n", keys = "<Leader>pg", desc = "Live grep" },
      { mode = "n", keys = "<Leader>pq", desc = "Pick quickfix" },
      { mode = "n", keys = "<Leader>ps", desc = "Pick document symbols" },
      { mode = "n", keys = "<Leader>pS", desc = "Pick workspace symbols" },
      { mode = "n", keys = "<Leader>r", desc = "+rename" },
      { mode = "n", keys = "<Leader>t", desc = "+trouble" },
      { mode = "n", keys = "<Leader>tr", desc = "Trouble references" },
      { mode = "n", keys = "<Leader>tq", desc = "Trouble quickfix" },
      { mode = "n", keys = "<Leader>tt", desc = "Trouble diagnostics" },
      { mode = "n", keys = "<Leader>x", desc = "Delete buffer" },
      miniclue.gen_clues.builtin_completion(),
      miniclue.gen_clues.g(),
      miniclue.gen_clues.marks(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.windows(),
      miniclue.gen_clues.z(),
    },
    window = {
      delay = 300,
    },
  })
end
