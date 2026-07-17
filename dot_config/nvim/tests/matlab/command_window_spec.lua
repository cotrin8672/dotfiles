describe("MATLAB command window", function()
	local cmdwin
	local source_bufnr
	local source_winid
	local connection
	local release

	local function output_marks()
		local namespace = vim.api.nvim_get_namespaces().MatlabCommandWindowOutput
		return vim.api.nvim_buf_get_extmarks(cmdwin._snapshot().bufnr, namespace, 0, -1, { details = true })
	end

	before_each(function()
		connection = "disconnected"
		release = nil
		package.loaded["config.matlab.core"] = {
			connection_state = function()
				return connection, release
			end,
		}
		package.loaded["config.matlab.command_window"] = nil
		cmdwin = require("config.matlab.command_window")
		cmdwin._reset_for_tests()

		source_bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, source_bufnr)
		source_winid = vim.api.nvim_get_current_win()
	end)

	after_each(function()
		cmdwin._reset_for_tests()
		if vim.api.nvim_buf_is_valid(source_bufnr) then
			vim.api.nvim_buf_delete(source_bufnr, { force = true })
		end
		package.loaded["config.matlab.command_window"] = nil
		package.loaded["config.matlab.core"] = nil
	end)

	it("shows lifecycle state in the winbar and keeps it out of the command buffer", function()
		cmdwin.submit("seed", { echo = false })
		cmdwin.open()
		local winid = cmdwin._snapshot().winid
		assert.are.equal("", cmdwin._snapshot().prompt)
		assert.are.equal(" MATLAB DISCONNECTED ", vim.wo[winid].winbar)
		assert.same({}, vim.api.nvim_buf_get_extmarks(cmdwin._snapshot().bufnr, -1, 0, -1, { details = true }))

		cmdwin.handle_connection_state("connecting")
		assert.are.equal("MATLAB STARTING…", cmdwin._snapshot().status_text)
		assert.are.equal("", cmdwin._snapshot().prompt)
		assert.are.equal(" MATLAB STARTING… ", vim.wo[winid].winbar)

		cmdwin.handle_connection_state("connected", { release = "R2024a" })
		cmdwin.handle_prompt_change("BUSY", false)
		assert.are.equal("MATLAB RUNNING…", cmdwin._snapshot().status_text)
		assert.are.equal(" MATLAB RUNNING… ", vim.wo[winid].winbar)
		cmdwin.handle_prompt_change("READY", true)
		assert.are.equal(">> ", cmdwin._snapshot().prompt)
		assert.is_nil(cmdwin._snapshot().status_text)
		assert.are.equal(" MATLAB R2024a ", vim.wo[winid].winbar)
	end)

	it("forwards source options and still echoes submitted commands", function()
		local received
		cmdwin.set_submit_callback(function(command, opts)
			received = { command = command, opts = opts }
			return true, nil
		end)

		assert.is_true(cmdwin.submit("x = 1;", { bufnr = 99 }))
		assert.are.equal(99, received.opts.bufnr)
		assert.same(
			{ ">> x = 1;", "" },
			vim.api.nvim_buf_get_lines(cmdwin._snapshot().bufnr, 0, -1, false)
		)
	end)

	it("strips warning sentinels and highlights warnings without opening", function()
		cmdwin.handle_connection_state("connected", { release = "R2024a" })
		cmdwin.handle_prompt_change("BUSY", false)
		cmdwin.handle_text("[", 0)
		cmdwin.handle_text("\bWarning: sample]", 0)
		cmdwin.handle_text("\b\n", 0)

		local lines = vim.api.nvim_buf_get_lines(cmdwin._snapshot().bufnr, 0, -1, false)
		assert.are.equal("Warning: sample", lines[1])
		assert.is_nil(cmdwin._snapshot().winid)
		assert.are.equal("WarningMsg", output_marks()[1][4].hl_group)
		assert.is_nil(output_marks()[1][4].line_hl_group)
	end)

	it("opens stderr output without stealing focus and highlights it", function()
		cmdwin.handle_connection_state("connected", { release = "R2024a" })
		cmdwin.handle_prompt_change("BUSY", false)
		cmdwin.handle_text("Error happened\n", 1)

		assert.is_true(vim.api.nvim_win_is_valid(cmdwin._snapshot().winid))
		assert.are.equal(source_winid, vim.api.nvim_get_current_win())
		assert.are.equal("ErrorMsg", output_marks()[1][4].hl_group)
		assert.is_nil(output_marks()[1][4].line_hl_group)
	end)

	it("does not carry a completed stderr line onto the next normal output", function()
		cmdwin.handle_connection_state("connected", { release = "R2024a" })
		cmdwin.handle_prompt_change("BUSY", false)
		cmdwin.handle_text("Error happened\n", 1)
		cmdwin.handle_text("cycle : 5000\n", 0)

		local lines = vim.api.nvim_buf_get_lines(cmdwin._snapshot().bufnr, 0, -1, false)
		assert.are.equal("Error happened", lines[1])
		assert.are.equal("cycle : 5000", lines[2])
		assert.are.equal(1, #output_marks())
		assert.are.equal(0, output_marks()[1][2])
		assert.are.equal("ErrorMsg", output_marks()[1][4].hl_group)
	end)

	it("ignores an empty stderr event instead of tainting later output", function()
		cmdwin.handle_connection_state("connected", { release = "R2024a" })
		cmdwin.handle_prompt_change("BUSY", false)
		cmdwin.handle_text("", 1)
		cmdwin.handle_text("cycle : 5000\n", 0)

		assert.are.equal("cycle : 5000", vim.api.nvim_buf_get_lines(cmdwin._snapshot().bufnr, 0, 1, false)[1])
		assert.same({}, output_marks())
	end)

	it("removes MATLAB error overstrike markers even when split across events", function()
		cmdwin.handle_connection_state("connected", { release = "R2024a" })
		cmdwin.handle_prompt_change("BUSY", false)
		cmdwin.handle_text("{", 1)
		cmdwin.handle_text("\b処理は途中で終了しました main_sweep (行 117)\n}", 1)
		cmdwin.handle_text("\b", 1)

		local lines = vim.api.nvim_buf_get_lines(cmdwin._snapshot().bufnr, 0, -1, false)
		assert.are.equal("処理は途中で終了しました main_sweep (行 117)", lines[1])
		assert.is_nil(lines[1]:find("\b", 1, true))
		assert.is_nil(lines[1]:find("{", 1, true))
		assert.is_nil(lines[1]:find("}", 1, true))
		assert.are.equal("ErrorMsg", output_marks()[1][4].hl_group)
	end)

	it("opens and focuses the command window for MATLAB input", function()
		connection = "connected"
		release = "R2024a"
		cmdwin.handle_connection_state(connection, { release = release })
		cmdwin.handle_input_prompt("Value: ")
		cmdwin.handle_prompt_change("INPUT", false)

		assert.are.equal("Value: ", cmdwin._snapshot().prompt)
		assert.are.equal(cmdwin._snapshot().winid, vim.api.nvim_get_current_win())
	end)

	it("follows output only while the cursor is at the prompt", function()
		connection = "connected"
		release = "R2024a"
		cmdwin.open()
		cmdwin.handle_prompt_change("READY", true)
		for index = 1, 20 do
			cmdwin.handle_text("line " .. index .. "\n", 0)
		end
		local winid = cmdwin._snapshot().winid
		assert.are.equal(vim.api.nvim_buf_line_count(cmdwin._snapshot().bufnr), vim.api.nvim_win_get_cursor(winid)[1])

		vim.api.nvim_win_set_cursor(winid, { 1, 0 })
		cmdwin.handle_text("while reading\n", 0)
		assert.are.equal(1, vim.api.nvim_win_get_cursor(winid)[1])

		vim.api.nvim_win_set_cursor(winid, { vim.api.nvim_buf_line_count(cmdwin._snapshot().bufnr), 0 })
		cmdwin.handle_text("at tail\n", 0)
		assert.are.equal(vim.api.nvim_buf_line_count(cmdwin._snapshot().bufnr), vim.api.nvim_win_get_cursor(winid)[1])
	end)

	it("closes with q without overriding normal-mode Esc", function()
		cmdwin.open()
		local bufnr = cmdwin._snapshot().bufnr
		assert.is_true(vim.fn.maparg("q", "n", false, true).buffer == 1)
		assert.are.equal("", vim.fn.maparg("<Esc>", "n"))
		assert.are.equal(bufnr, vim.api.nvim_win_get_buf(cmdwin._snapshot().winid))
	end)
end)
