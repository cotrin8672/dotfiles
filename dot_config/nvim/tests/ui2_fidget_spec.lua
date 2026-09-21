describe("ui2 to Fidget message routing", function()
	local ui2_messages
	local original_ui2_messages
	local original_fidget
	local notifications
	local forwarded

	before_each(function()
		notifications = {}
		forwarded = {}
		ui2_messages = {
			msg_show = function(...)
				forwarded[#forwarded + 1] = { ... }
			end,
			msg_clear = function()
				forwarded[#forwarded + 1] = { "clear" }
			end,
		}

		original_ui2_messages = package.loaded["vim._core.ui2.messages"]
		original_fidget = package.loaded.fidget
		package.loaded["vim._core.ui2.messages"] = ui2_messages
		package.loaded.fidget = {
			notify = function(message, level, opts)
				notifications[#notifications + 1] = { message = message, level = level, opts = opts }
			end,
		}
		package.loaded["config.ui2_fidget"] = nil
		require("config.ui2_fidget").setup()
	end)

	after_each(function()
		package.loaded["vim._core.ui2.messages"] = original_ui2_messages
		package.loaded.fidget = original_fidget
		package.loaded["config.ui2_fidget"] = nil
	end)

	it("routes ordinary messages to Fidget", function()
		ui2_messages.msg_show("list_cmd", { { 0, "11 lines yanked", 0 } }, false, true, false, 7, "")
		vim.wait(100, function()
			return #notifications == 1
		end)

		assert.are.equal(0, #forwarded)
		assert.are.equal("11 lines yanked", notifications[1].message)
		assert.are.equal("nvim_message", notifications[1].opts.group)
		assert.are.equal("ui2:7", notifications[1].opts.key)
	end)

	it("keeps errors and long command output in ui2", function()
		ui2_messages.msg_show("emsg", { { 0, "failure", 0 } }, false, true, false, 8, "")
		ui2_messages.msg_show("list_cmd", { { 0, "long output", 0 } }, false, true, false, 9, "typed_cmd")
		ui2_messages.msg_show("", { { 0, "first\nsecond", 0 } }, false, true, false, 10, "")

		assert.are.equal(3, #forwarded)
		assert.are.equal(0, #notifications)
	end)

	it("replaces and appends messages using the same Fidget item", function()
		ui2_messages.msg_show("echo", { { 0, "first", 0 } }, false, true, false, 10, "")
		ui2_messages.msg_show("echo", { { 0, " replacement", 0 } }, true, true, false, 11, "")
		ui2_messages.msg_show("echo", { { 0, " appended", 0 } }, false, true, true, 11, "")
		vim.wait(100, function()
			return #notifications == 3
		end)

		assert.are.equal("ui2:10", notifications[1].opts.key)
		assert.are.equal("ui2:10", notifications[2].opts.key)
		assert.are.equal(" replacement appended", notifications[3].message)
		assert.are.equal("ui2:10", notifications[3].opts.key)
	end)
end)
