local float = require("shared.float")

return {
  name = "blink.cmp",
  "Saghen/blink.cmp",
  event = "InsertEnter",
  config = function()
    require("blink.cmp").setup({
      keymap = {
        preset = "enter",
      },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        accept = {
          auto_brackets = {
            kind_resolution = {
              blocked_filetypes = {
                "java",
                "kotlin",
              },
            },
            semantic_token_resolution = {
              blocked_filetypes = {
                "java",
                "kotlin",
              },
            },
          },
        },
        menu = {
          winblend = float.blend,
        },
        documentation = {
          auto_show = false,
          window = {
            winblend = float.blend,
          },
        },
      },
      sources = {
        default = {
          "buffer",
          "path",
          "lsp",
        },
      },
    })
  end,
}
