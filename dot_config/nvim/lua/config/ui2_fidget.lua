local M = {}

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
	local ui2 = require("vim._core.ui2")
	local original_msg_show = ui2_messages.msg_show
	local original_msg_clear = ui2_messages.msg_clear
	local last_key
	local last_text

	ui2_messages.msg_show = function(kind, content, replace_last, history, append, id, trigger)
		local text = message_text(content)
		local targets = ui2.cfg.msg.targets
		local target = targets[trigger] or targets[kind] or ui2.cfg.msg.target
		local cmd = ui2.cmd
		local special = kind == "search_cmd" or kind == "search_count" or kind == "empty" or kind == "wildlist"
		local blocked = cmd and (cmd.prompt or cmd.level > 0 or cmd.expand > 0)
		if target ~= "cmd" or special or blocked or text:find("\n", 1, true) then
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
