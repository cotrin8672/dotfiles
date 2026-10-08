local M = {}

---@param item snacks.picker.finder.Item
---@return string
local function item_key(item)
	return table.concat({
		item.file or "",
		item.pos and item.pos[1] or "",
		item.pos and item.pos[2] or "",
		item.text or "",
	}, ":")
end

---@param opts snacks.picker.grep.Config
---@param ctx snacks.picker.finder.ctx
---@return snacks.picker.finder.result
function M.finder(opts, ctx)
	local Finder = require("snacks.picker.core.finder")
	local Config = require("snacks.picker.config")
	local grep_kensaku = require("plugins.snacks-kensaku.grep_kensaku")

	local merged = Finder.multi({
		Config.finder("grep"),
		grep_kensaku.finder,
	})

	local result = merged(opts, ctx)
	if type(result) == "table" then
		local items = {}
		local seen = {}
		for _, item in ipairs(result) do
			local key = item_key(item)
			if not seen[key] then
				seen[key] = true
				items[#items + 1] = item
			end
		end
		return items
	end

	return function(cb)
		local seen = {}
		result(function(item)
			local key = item_key(item)
			if seen[key] then
				return
			end
			seen[key] = true
			cb(item)
		end)
	end
end

M.format = "file"
M.regex = true
M.show_empty = true
M.live = true
M.supports_live = true

return M
