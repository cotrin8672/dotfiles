local M = {}
local mode_accent = require("ui.mode_accent")
local initialized = false

local function hex_to_rgb(hex)
	local s = hex:gsub("#", "")
	if #s ~= 6 then
		return 0, 0, 0
	end
	return tonumber(s:sub(1, 2), 16) or 0, tonumber(s:sub(3, 4), 16) or 0, tonumber(s:sub(5, 6), 16) or 0
end

local function rgb_to_hex(r, g, b)
	return string.format(
		"#%02X%02X%02X",
		math.max(0, math.min(255, r)),
		math.max(0, math.min(255, g)),
		math.max(0, math.min(255, b))
	)
end

local function mix(hex_a, hex_b, ratio)
	local ar, ag, ab = hex_to_rgb(hex_a)
	local br, bg, bb = hex_to_rgb(hex_b)
	local r = math.floor(ar * (1 - ratio) + br * ratio + 0.5)
	local g = math.floor(ag * (1 - ratio) + bg * ratio + 0.5)
	local b = math.floor(ab * (1 - ratio) + bb * ratio + 0.5)
	return rgb_to_hex(r, g, b)
end

function M.refresh()
	local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = true })
	local statusline = vim.api.nvim_get_hl(0, { name = "MiniStatuslineModeNormal", link = true })
	local tabline = vim.api.nvim_get_hl(0, { name = "TabLineSel", link = true })
	local base_bg = normal.bg or statusline.fg or tabline.fg
	local color = mode_accent.get_accent_color()
	if not base_bg or not color then
		return
	end
	local line_bg = mix(string.format("#%06x", base_bg), color, 0.35)
	vim.api.nvim_set_hl(0, "CursorLine", { bg = line_bg })
	vim.api.nvim_set_hl(0, "CursorColumn", { bg = line_bg })
	vim.api.nvim_set_hl(0, "CursorLineNr", { fg = color, bold = true })
end

function M.setup()
	if initialized then
		return
	end
	initialized = true

	local group = vim.api.nvim_create_augroup("CursorModeColor", { clear = true })
	vim.api.nvim_create_autocmd({ "ModeChanged", "WinEnter", "BufEnter", "ColorScheme", "VimEnter" }, {
		group = group,
		callback = function()
			M.refresh()
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "VeryLazy",
		callback = function()
			M.refresh()
		end,
	})

	M.refresh()
end

return M
