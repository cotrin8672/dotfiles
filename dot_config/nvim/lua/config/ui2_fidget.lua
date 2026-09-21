local M = {}

local routed_kinds = {
	[""] = true,
	echo = true,
	echomsg = true,
	lua_print = true,
	quickfix = true,
	undo = true,
}

local installed = false

local function message_text(content)
	local chunks = {}
	for _, chunk in ipairs(content) do
		chunks[#chunks + 1] = chunk[2]
	end
	return table.concat(chunks)
end

function M.setup()
	if installed then
		return
	end

	local ui2_messages = require("vim._core.ui2.messages")
	local original_msg_show = ui2_messages.msg_show
	local original_msg_clear = ui2_messages.msg_clear
	local last_key
	local last_text

	ui2_messages.msg_show = function(kind, content, replace_last, history, append, id, trigger)
		local text = message_text(content)
		local routed = routed_kinds[kind] or (kind == "list_cmd" and trigger == "")
		if not routed or text:find("\n", 1, true) then
			last_key = nil
			last_text = nil
			return original_msg_show(kind, content, replace_last, history, append, id, trigger)
		end

		if append and last_text then
			text = last_text .. text
		end
		if text == "" then
			return
		end

		local key = (replace_last or append) and last_key or nil
		key = key or ("ui2:%s"):format(id)
		last_key = key
		last_text = text

		vim.schedule(function()
			require("fidget").notify(text, vim.log.levels.INFO, {
				group = "nvim_message",
				key = key,
				ttl = 2,
				skip_history = true,
			})
		end)
	end

	ui2_messages.msg_clear = function(...)
		last_key = nil
		last_text = nil
		return original_msg_clear(...)
	end

	installed = true
end

return M
