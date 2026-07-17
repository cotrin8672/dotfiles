describe("MATLAB user commands", function()
	local bufnr
	local commands
	local next_cell_line
	local submit_ok
	local submitted
	local notifications
	local original_notify

	before_each(function()
		next_cell_line = nil
		submit_ok = true
		submitted = {}
		notifications = {}
		original_notify = vim.notify
		vim.notify = function(message, level)
			table.insert(notifications, { message = message, level = level })
		end

		package.loaded["config.matlab.core"] = {
			get_diagnostic_client = function()
				return nil
			end,
			get_exec_client = function()
				return nil
			end,
			_snapshot = function()
				return { state = "disconnected", queue_length = 0 }
			end,
			request_diagnostic = function()
				return nil, "not available"
			end,
		}
		package.loaded["config.matlab.exec"] = {
			current_cell_command = function()
				return "x = 1;", nil, next_cell_line
			end,
			visual_selection_command = function()
				return "selected", nil
			end,
		}
		package.loaded["config.matlab.command_window"] = {
			submit = function(command, opts)
				table.insert(submitted, { command = command, opts = opts })
				if submit_ok then
					return true, nil
				end
				return false, "submit failed"
			end,
		}
		package.loaded["config.matlab.commands"] = nil
		commands = require("config.matlab.commands")

		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, bufnr)
		local lines = {}
		for index = 1, 100 do
			lines[index] = "x = " .. index .. ";"
		end
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		vim.api.nvim_win_set_cursor(0, { 5, 0 })
	end)

	after_each(function()
		vim.notify = original_notify
		vim.api.nvim_buf_delete(bufnr, { force = true })
		package.loaded["config.matlab.commands"] = nil
		package.loaded["config.matlab.command_window"] = nil
		package.loaded["config.matlab.exec"] = nil
		package.loaded["config.matlab.core"] = nil
	end)

	it("moves to and centers the next cell after execution is accepted", function()
		next_cell_line = 60
		assert.is_true(commands.run_cell())
		assert.are.equal(60, vim.api.nvim_win_get_cursor(0)[1])
		assert.is_true(math.abs(vim.fn.winline() - math.floor(vim.fn.winheight(0) / 2)) <= 2)
		assert.are.equal(bufnr, submitted[1].opts.bufnr)
	end)

	it("does not move when submission fails", function()
		next_cell_line = 60
		submit_ok = false
		assert.is_false(commands.run_cell())
		assert.are.equal(5, vim.api.nvim_win_get_cursor(0)[1])
		assert.matches("submit failed", notifications[1].message)
	end)

	it("keeps the cursor in the final cell", function()
		assert.is_true(commands.run_cell())
		assert.are.equal(5, vim.api.nvim_win_get_cursor(0)[1])
		assert.are.equal(1, #submitted)
	end)

	it("submits visual selections with their source buffer context", function()
		assert.is_true(commands.run_visual_selection())
		assert.are.equal("selected", submitted[1].command)
		assert.are.equal(bufnr, submitted[1].opts.bufnr)
	end)
end)
