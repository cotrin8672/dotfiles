describe("MATLAB execution commands", function()
	local bufnr
	local exec
	local evaluated

	before_each(function()
		package.loaded["config.matlab.core"] = {
			enqueue_eval = function(command, opts)
				evaluated = { command = command, opts = opts }
				return true, nil
			end,
		}
		package.loaded["config.matlab.exec"] = nil
		exec = require("config.matlab.exec")
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, bufnr)
	end)

	after_each(function()
		vim.api.nvim_buf_delete(bufnr, { force = true })
		package.loaded["config.matlab.exec"] = nil
		package.loaded["config.matlab.core"] = nil
	end)

	it("runs a MATLAB file by its script name without wrapping it in run", function()
		local path = vim.fn.getcwd() .. "/main.m"
		vim.api.nvim_buf_set_name(bufnr, path)
		local command = assert(exec.command_from_current_file())
		assert.are.equal("main", command)
	end)

	it("extracts exact charwise, linewise, reverse, and blockwise selections", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"alpha = 10; beta = 20;",
			"aa11zz",
			"bb22yy",
		})

		assert.are.equal("10; beta = 20", assert(exec.visual_selection_command(
			{ bufnr, 1, 9, 0 },
			{ bufnr, 1, 21, 0 },
			"v"
		)))
		assert.are.equal("aa11zz\nbb22yy", assert(exec.visual_selection_command(
			{ bufnr, 2, 1, 0 },
			{ bufnr, 3, 1, 0 },
			"V"
		)))
		assert.are.equal("10; beta = 20", assert(exec.visual_selection_command(
			{ bufnr, 1, 21, 0 },
			{ bufnr, 1, 9, 0 },
			"v"
		)))
		assert.are.equal("11\n22", assert(exec.visual_selection_command(
			{ bufnr, 2, 3, 0 },
			{ bufnr, 3, 4, 0 },
			"\22"
		)))
	end)

	it("lets Neovim preserve multibyte and exclusive-selection semantics", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "α\tfoo = 1;" })
		assert.are.equal("foo", assert(exec.visual_selection_command(
			{ bufnr, 1, 4, 0 },
			{ bufnr, 1, 6, 0 },
			"v"
		)))

		local old_selection = vim.o.selection
		vim.o.selection = "exclusive"
		local command = assert(exec.visual_selection_command(
			{ bufnr, 1, 4, 0 },
			{ bufnr, 1, 7, 0 },
			"v"
		))
		vim.o.selection = old_selection
		assert.are.equal("foo", command)
	end)

	it("returns the next cell marker with the current cell command", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"%% first",
			"x = 1;",
			"%% second",
			"y = 2;",
		})
		vim.api.nvim_win_set_cursor(0, { 2, 0 })

		local command, err, next_line, start_line, end_line = exec.current_cell_command()
		assert.is_nil(err)
		assert.are.equal("%% first\nx = 1;", command)
		assert.are.equal(3, next_line)
		assert.are.equal(1, start_line)
		assert.are.equal(2, end_line)

		vim.api.nvim_win_set_cursor(0, { 4, 0 })
		command, err, next_line = exec.current_cell_command()
		assert.is_nil(err)
		assert.are.equal("%% second\ny = 2;", command)
		assert.is_nil(next_line)
	end)

	it("passes the source buffer to the execution client", function()
		local path = vim.fn.getcwd() .. "/main.m"
		vim.api.nvim_buf_set_name(bufnr, path)
		assert.is_true(exec.run_file())
		assert.are.equal(bufnr, evaluated.opts.bufnr)
		assert.are.equal("main", evaluated.command)
	end)
end)
