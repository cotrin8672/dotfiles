describe("MATLAB editing keymaps", function()
	local bufnr

	before_each(function()
		require("config.matlab.editing").setup()
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, bufnr)
		vim.bo[bufnr].filetype = "matlab"
	end)

	after_each(function()
		vim.api.nvim_buf_delete(bufnr, { force = true })
		package.loaded["blink.cmp"] = nil
	end)

	it("maps the workspace variable browser to leader fm", function()
		local mapping = vim.fn.maparg(" fm", "n", false, true)

		assert.are.equal("<Cmd>MatlabWorkspace<CR>", mapping.rhs)
		assert.same({}, vim.fn.maparg(" mv", "n", false, true))
		assert.same({}, vim.fn.maparg(" mW", "n", false, true))
	end)

	it("maps the MATLAB session picker to leader fc", function()
		local mapping = vim.fn.maparg(" fc", "n", false, true)

		assert.are.equal("<Cmd>MatlabSessions<CR>", mapping.rhs)
		assert.are.equal("Matlab sessions", mapping.desc)
	end)

	it("maps exact selection execution and interrupt", function()
		assert.are.equal(":<C-u>MatlabRunVisual<CR>", vim.fn.maparg(" ms", "x", false, true).rhs)
		assert.are.equal("<Cmd>MatlabInterrupt<CR>", vim.fn.maparg(" mi", "n", false, true).rhs)
	end)

	it("maps K to MATLAB help", function()
		local mapping = vim.fn.maparg("K", "n", false, true)
		assert.are.equal("Matlab help", mapping.desc)
		assert.is_function(mapping.callback)
	end)

	it("does not rescan the buffer while moving inside a MATLAB section", function()
		vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".m")
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "%% first", "a = 1;", "b = 2;", "%% second", "c = 3;" })
		vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })
		vim.api.nvim_win_set_cursor(0, { 2, 0 })
		vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })

		local get_lines = vim.api.nvim_buf_get_lines
		local calls = 0
		vim.api.nvim_buf_get_lines = function(...)
			calls = calls + 1
			return get_lines(...)
		end
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
		vim.api.nvim_buf_get_lines = get_lines

		assert.are.equal(0, calls)

		vim.api.nvim_win_set_cursor(0, { 5, 0 })
		vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr })
		local namespace = vim.api.nvim_create_namespace("MatlabCurrentSection")
		local marks = vim.api.nvim_buf_get_extmarks(bufnr, namespace, 0, -1, {})
		assert.same({ 3, 4 }, vim.tbl_map(function(mark)
			return mark[2]
		end, marks))
	end)

	it("rescans during insert only when section boundaries change", function()
		vim.api.nvim_buf_set_name(bufnr, vim.fn.tempname() .. ".m")
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "%% first", "a = 1;", "%% second" })
		vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })
		vim.api.nvim_win_set_cursor(0, { 2, 0 })

		local get_lines = vim.api.nvim_buf_get_lines
		local calls = 0
		vim.api.nvim_buf_get_lines = function(...)
			calls = calls + 1
			return get_lines(...)
		end
		vim.api.nvim_set_current_line("a = 2;")
		vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })
		assert.are.equal(0, calls)

		vim.api.nvim_set_current_line("%% inserted")
		vim.api.nvim_exec_autocmds("TextChangedI", { buffer = bufnr })
		vim.api.nvim_buf_get_lines = get_lines
		assert.are.equal(1, calls)
	end)

	it("repairs a missing split join mapping in an already open MATLAB buffer", function()
		vim.keymap.del("n", "<leader>s", { buffer = bufnr })

		require("config.matlab.editing").setup()

		local mapping = vim.fn.maparg(" s", "n", false, true)
		assert.are.equal("Matlab split/join", mapping.desc)
		assert.is_function(mapping.callback)
	end)

	it("routes the global TreeSJ key to MATLAB SplitJoin as a fallback", function()
		local splitjoin_calls = 0
		local treesj_calls = 0
		local original_splitjoin = package.loaded["config.matlab.splitjoin"]
		local original_treesj = package.loaded.treesj
		package.loaded["config.matlab.splitjoin"] = {
			toggle = function()
				splitjoin_calls = splitjoin_calls + 1
			end,
		}
		package.loaded.treesj = {
			toggle = function()
				treesj_calls = treesj_calls + 1
			end,
		}

		local config_root = vim.fn.getcwd() .. "/dot_config/nvim"
		local spec = dofile(config_root .. "/lua/plugins/treesj.lua")
		local callback = spec.keys[1][2]

		assert.is_function(callback)
		callback()
		vim.bo[bufnr].filetype = "lua"
		callback()

		package.loaded["config.matlab.splitjoin"] = original_splitjoin
		package.loaded.treesj = original_treesj
		assert.are.equal(1, splitjoin_calls)
		assert.are.equal(1, treesj_calls)
	end)

	it("accepts Blink completion before applying MATLAB continuation newline", function()
		local accepted = 0
		package.loaded["blink.cmp"] = {
			accept = function()
				accepted = accepted + 1
				return true
			end,
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "value = fo(" })
		vim.api.nvim_win_set_cursor(0, { 1, 11 })

		assert.are.equal("", require("config.matlab.editing").confirm_completion_or_newline())
		assert.are.equal(1, accepted)
	end)

	it("uses MATLAB continuation newline only when Blink does not accept", function()
		package.loaded["blink.cmp"] = {
			accept = function()
				return false
			end,
		}
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "value = foo(" })
		vim.api.nvim_win_set_cursor(0, { 1, 12 })

		assert.are.equal(" ...<CR>", require("config.matlab.editing").confirm_completion_or_newline())
	end)
end)
