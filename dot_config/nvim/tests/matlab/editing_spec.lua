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

	it("maps exact selection execution and interrupt", function()
		assert.are.equal(":<C-u>MatlabRunVisual<CR>", vim.fn.maparg(" ms", "x", false, true).rhs)
		assert.are.equal("<Cmd>MatlabInterrupt<CR>", vim.fn.maparg(" mi", "n", false, true).rhs)
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
