local M = {}

local function to_hex(n)
	return type(n) == "number" and string.format("#%06x", n) or nil
end

local function hl(name, key)
	local ok, v = pcall(vim.api.nvim_get_hl, 0, { name = name, link = true })
	return ok and v and to_hex(v[key]) or nil
end

local lualine_hl = {
	normal = "lualine_a_normal",
	insert = "lualine_a_insert",
	visual = "lualine_a_visual",
	command = "lualine_a_command",
	replace = "lualine_a_replace",
	terminal = "lualine_a_terminal",
}

local mode_colors = {}

function M.set_mode_colors(colors)
	mode_colors = colors or {}
end

function M.get_mode_key()
	local m = vim.api.nvim_get_mode().mode
	if m:find("^i") then
		return "insert"
	end
	if m:find("^[vV]") or m == "\22" then
		return "visual"
	end
	if m:find("^c") then
		return "command"
	end
	if m:find("^[Rr]") then
		return "replace"
	end
	if m:find("^t") then
		return "terminal"
	end
	return "normal"
end

function M.get_mode_color()
	local key = M.get_mode_key()
	local explicit_color = mode_colors[key]
	if type(explicit_color) ~= "string" or explicit_color == "" then
		explicit_color = nil
	end

	return hl(lualine_hl[key], "bg")
		or explicit_color
		or hl("CursorLineNr", "fg")
		or hl("LineNr", "fg")
		or hl("StatusLine", "fg")
		or hl("Normal", "fg")
end

function M.get_submode_color()
	local sm = package.loaded["nvim-submode"]
	if sm and type(sm.get_submode_color) == "function" then
		local c = sm.get_submode_color()
		if type(c) == "string" and c ~= "" then
			return c
		end
	end

	return nil
end

function M.get_accent_color()
	return M.get_submode_color() or M.get_mode_color()
end

return M
