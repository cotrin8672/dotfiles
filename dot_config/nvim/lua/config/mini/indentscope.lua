return function()
  local indentscope = require("mini.indentscope")

  local function apply_hl()
    local fg

    local ok_colours, colours = pcall(require, "everforest.colours")
    local ok_theme, theme = pcall(require, "everforest")
    if ok_colours and ok_theme then
      local palette = colours.generate_palette(theme.config, vim.o.background)
      fg = palette.grey1
    end

    if not fg then
      local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = "Whitespace", link = true })
      if ok and hl and hl.fg then
        fg = string.format("#%06x", hl.fg)
      end
    end

    vim.api.nvim_set_hl(0, "MiniIndentscopeSymbol", {
      fg = fg,
      nocombine = true,
    })
    vim.api.nvim_set_hl(0, "MiniIndentscopeSymbolOff", {
      fg = fg,
      nocombine = true,
    })
  end

  apply_hl()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("MiniIndentscopeColors", { clear = true }),
    callback = apply_hl,
  })

  indentscope.setup({
    draw = {
      delay = 0,
      animation = indentscope.gen_animation.none(),
      priority = 200,
    },
    symbol = "│",
  })
end
