return {
  'sphamba/smear-cursor.nvim',
  event = 'VeryLazy',
  opts = function()
    local cursor_color = '#9CBBC9'
    local ok, base_color = pcall(require, 'wisteria.lib.base_color')
    if ok and base_color and base_color.wst and base_color.wst.sky then
      cursor_color = base_color.wst.sky
    end
    return {
      cursor_color = cursor_color,
      cursor_color_insert_mode = cursor_color,
      stiffness = 0.5,
      trailing_stiffness = 0.5,
      matrix_pixel_threshold = 0.5,
    }
  end,
}
