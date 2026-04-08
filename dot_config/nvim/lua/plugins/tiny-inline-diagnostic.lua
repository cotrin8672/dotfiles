
return {
  name = "tiny-inline-diagnostic.nvim",
  "rachartier/tiny-inline-diagnostic.nvim",
  event = "VeryLazy",
  opts = {
    preset = "modern",
    options = {
      severity = {
        vim.diagnostic.severity.ERROR,
        vim.diagnostic.severity.WARN,
      },
      show_all_diags_on_cursorline = true,
      multilines = {
        enabled = true,
      },
      add_messages = {
        messages = true,
        display_count = true,
        use_max_severity = true,
      },
    },
  },
  config = function(_, opts)
    require("tiny-inline-diagnostic").setup(opts)
    vim.diagnostic.config({ virtual_text = false })
  end,
}
