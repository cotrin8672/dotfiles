describe("MATLAB session picker", function()
	local picker_opts
	local selected
	local preview_bufnr

	before_each(function()
		selected = nil
		preview_bufnr = vim.api.nvim_create_buf(false, true)
		vim.bo[preview_bufnr].buftype = "prompt"

		package.loaded["config.matlab.core"] = {
			list_sessions = function()
				return {
					{ id = 11, index = 1, current = false, state = "connected", root_dir = "C:/repo/one" },
					{ id = 22, index = 2, current = true, state = "connecting", root_dir = "C:/repo/two" },
				}
			end,
			select_session = function(session_id)
				selected = session_id
				return true, nil
			end,
		}
		package.loaded["config.matlab.command_window"] = {
			buffer_for_session = function(session_id)
				assert.are.equal(11, session_id)
				return preview_bufnr
			end,
		}
		package.loaded["config.matlab.session_picker"] = nil
		picker_opts = require("config.matlab.session_picker")._picker_options()
	end)

	after_each(function()
		package.loaded["config.matlab.session_picker"] = nil
		package.loaded["config.matlab.command_window"] = nil
		package.loaded["config.matlab.core"] = nil
		if vim.api.nvim_buf_is_valid(preview_bufnr) then
			vim.api.nvim_buf_delete(preview_bufnr, { force = true })
		end
	end)

	it("previews the selected session buffer without selecting that session", function()
		local entries = picker_opts.finder()
		local shown
		picker_opts.preview({
			item = entries[1],
			win = vim.api.nvim_get_current_win(),
			preview = {
				set_title = function() end,
				set_buf = function(_, bufnr)
					shown = bufnr
					vim.api.nvim_win_set_buf(0, bufnr)
				end,
			},
		})

		assert.are.equal(preview_bufnr, shown)
		assert.is_nil(selected)
		assert.are.equal("enter_preview", picker_opts.win.list.keys["<C-l>"])
	end)

	it("selects the session only on confirm", function()
		local closed = false
		picker_opts.confirm({ close = function()
			closed = true
		end }, picker_opts.finder()[1])

		assert.are.equal(11, selected)
		assert.is_true(closed)
	end)

	it("enters Preview without selecting its session", function()
		local focused
		local shown
		picker_opts.actions.enter_preview({
			focus = function(_, win)
				focused = win
			end,
			preview = {
				set_title = function() end,
				set_buf = function(_, bufnr)
					shown = bufnr
				end,
				win = { valid = function()
					return false
				end },
			},
		}, picker_opts.finder()[1])

		assert.are.equal("preview", focused)
		assert.are.equal(preview_bufnr, shown)
		assert.is_nil(selected)
	end)
end)
