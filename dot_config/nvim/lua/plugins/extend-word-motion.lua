return {
	"s-show/extend_word_motion.nvim",
	event = "VeryLazy",
	dependencies = {
		"sirasagi62/tinysegmenter.nvim",
		"chrisgrieser/nvim-spider",
	},
	config = function()
		local japanese = require("extend_word_motion")
		japanese.setup({ extend_motions = {} })
		local spider = require("spider")
		-- Let Spider reach non-ASCII runs from code; TinySegmenter takes over there.
		local spider_opts = { customPatterns = { patterns = { "[\128-\255]+" }, overrideDefault = false } }
		-- Use one Ex mapping for both motions so operator dot-repeat rechecks the cursor.
		vim.api.nvim_create_user_command("WordMotion", function(command)
			local byte = vim.api.nvim_get_current_line():byte(vim.fn.col("."))
			if byte and byte >= 128 then
				japanese.handle_motion(command.args)
			else
				spider.motion(command.args, spider_opts)
			end
		end, { nargs = 1 })
		for _, key in ipairs({ "w", "b", "e", "ge" }) do
			vim.keymap.set({ "n", "x", "o" }, key, "<Cmd>WordMotion " .. key .. "<CR>", { desc = "Word motion: " .. key })
		end
	end,
}
