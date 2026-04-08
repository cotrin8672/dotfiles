
return {
  name = "barbar.nvim",
  "romgrk/barbar.nvim",
  event = "VeryLazy",
  dependencies = {
    "mini.icons",
    "gitsigns.nvim",
  },
  init = function()
    vim.g.barbar_auto_setup = false
  end,
  opts = {
    animation = true,
    auto_hide = false,
    clickable = true,
    focus_on_close = "left",
    highlight_visible = false,
    highlight_inactive_file_icons = false,
    icons = {
      button = "",
      filetype = {
        custom_colors = false,
      },
      separator = { left = "┃", right = "" },
      inactive = {
        separator = { left = "┃", right = "" },
      },
    },
    maximum_padding = 2,
    minimum_padding = 2,
  },
  config = function(_, opts)
    require("barbar").setup(opts)
    local barbar_icons = require("barbar.icons")
    local barbar_hl = require("barbar.utils.highlight")
    local barbar_render = require("barbar.ui.render")

    local function get_hl(name)
      local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
      if not ok then
        return {}
      end
      return hl
    end

    local function apply_barbar_colors()
      local normal = get_hl("Normal")
      local comment = get_hl("Comment")
      local tabline = get_hl("TabLine")
      local line_bg = tabline.bg or normal.bg
      local active_fg = normal.fg or tabline.fg
      local inactive_fg = comment.fg or tabline.fg or normal.fg
      local separator_fg = tabline.fg or comment.fg or normal.fg

      local function set(group, spec)
        local hl = get_hl(group)
        vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", hl, spec))
      end

      for _, group in ipairs({
        "BufferCurrent",
        "BufferCurrentIndex",
        "BufferCurrentMod",
        "BufferCurrentSign",
        "BufferCurrentTarget",
        "BufferCurrentBtn",
        "BufferVisible",
        "BufferVisibleIndex",
        "BufferVisibleMod",
        "BufferVisibleSign",
        "BufferVisibleTarget",
        "BufferVisibleBtn",
      }) do
        set(group, {
          fg = active_fg,
          bg = line_bg,
          bold = false,
          italic = false,
        })
      end

      for _, group in ipairs({
        "BufferInactive",
        "BufferInactiveIndex",
        "BufferInactiveMod",
        "BufferInactiveSign",
        "BufferInactiveTarget",
        "BufferInactiveBtn",
        "BufferAlternate",
        "BufferAlternateIndex",
        "BufferAlternateMod",
        "BufferAlternateSign",
        "BufferAlternateTarget",
        "BufferAlternateBtn",
      }) do
        set(group, {
          fg = inactive_fg,
          bg = line_bg,
          bold = false,
          italic = false,
        })
      end

      for _, group in ipairs({
        "BufferCurrentSeparator",
        "BufferVisibleSeparator",
        "BufferInactiveSeparator",
        "BufferAlternateSeparator",
      }) do
        set(group, {
          fg = separator_fg,
          bg = line_bg,
          bold = false,
          italic = false,
        })
      end

      for _, group in ipairs({
        "BufferTabpageFill",
        "BufferOffset",
        "BufferScrollArrow",
        "BufferTabpages",
        "BufferTabpagesSep",
      }) do
        set(group, {
          bg = line_bg,
        })
      end

      barbar_hl.reset_cache()
      barbar_icons.set_highlights()
      vim.schedule(function()
        barbar_render.update()
      end)
    end

    apply_barbar_colors()
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "*",
      callback = apply_barbar_colors,
    })

    local function update_barbar_visibility()
      if vim.bo.filetype == "ministarter" then
        vim.o.showtabline = 0
        return
      end

      vim.o.showtabline = 2
    end

    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "FileType" }, {
      callback = update_barbar_visibility,
    })
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniStarterOpened",
      callback = update_barbar_visibility,
    })
    vim.schedule(update_barbar_visibility)

    local map = vim.keymap.set
    local key_opts = { noremap = true, silent = true }
    map("n", "<Tab>", "<Cmd>BufferNext<CR>", key_opts)
    map("n", "<S-Tab>", "<Cmd>BufferPrevious<CR>", key_opts)
    map("n", "<leader>x", function()
      MiniBufremove.delete(0, false)
    end, key_opts)
  end,
}
