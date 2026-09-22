describe("MATLAB endwise", function()
	local bufnr

	before_each(function()
		package.loaded["blink.cmp"] = {
			accept = function()
				return false
			end,
		}
		vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/nvim-treesitter-endwise")
		vim.cmd("runtime plugin/nvim-treesitter-endwise.lua")

		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(bufnr)
		vim.bo[bufnr].filetype = "matlab"
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"function addKey(obj, name, extractor)",
			"    arguments",
		})
		vim.treesitter.start(bufnr, "matlab")
		vim.treesitter.get_parser(bufnr, "matlab"):parse()
		require("nvim-treesitter.endwise").attach(bufnr)
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("inserts end after an arguments header", function()
		local outer_indent = string.rep(" ", vim.fn.shiftwidth())
		local body_indent = outer_indent .. outer_indent
		vim.api.nvim_win_set_cursor(0, { 2, #outer_indent + #"arguments" - 1 })
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a<CR>", true, false, true), "xt", false)

		assert.is_true(vim.wait(1000, function()
			return vim.api.nvim_buf_line_count(bufnr) == 4
		end, 10))
		assert.same({
			"function addKey(obj, name, extractor)",
			outer_indent .. "arguments",
			body_indent,
			outer_indent .. "end",
		}, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
	end)

	it("does not insert end after an argument declaration", function()
		local outer_indent = string.rep(" ", vim.fn.shiftwidth())
		local body_indent = outer_indent .. outer_indent
		local endwise_ran = false
		vim.api.nvim_create_autocmd("User", {
			pattern = "PostNvimTreesitterEndwiseCR",
			once = true,
			callback = function()
				endwise_ran = true
			end,
		})
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"function keys = getKey(id)",
			outer_indent .. "arguments",
			body_indent .. "id (1, 1) string",
			outer_indent .. "end",
			"end",
		})
		vim.treesitter.get_parser(bufnr, "matlab"):parse()
		vim.api.nvim_win_set_cursor(0, { 3, #body_indent + #"id (1, 1) string" - 1 })
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a<CR>", true, false, true), "xt", false)

		assert.is_true(vim.wait(1000, function()
			return endwise_ran
		end, 10))
		assert.same({
			"function keys = getKey(id)",
			outer_indent .. "arguments",
			body_indent .. "id (1, 1) string",
			"",
			outer_indent .. "end",
			"end",
		}, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
	end)

	it("inserts end after a function header", function()
		vim.api.nvim_buf_delete(bufnr, { force = true })
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(bufnr)
		vim.bo[bufnr].filetype = "matlab"
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"methods",
			"    function addKey(obj, name, extractor)",
		})
		vim.treesitter.start(bufnr, "matlab")
		vim.treesitter.get_parser(bufnr, "matlab"):parse()
		require("nvim-treesitter.endwise").attach(bufnr)
		local outer_indent = string.rep(" ", vim.fn.shiftwidth())
		local body_indent = outer_indent .. outer_indent
		vim.api.nvim_win_set_cursor(0, { 2, #outer_indent + #"function addKey(obj, name, extractor)" - 1 })
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("a<CR>", true, false, true), "xt", false)

		assert.is_true(vim.wait(1000, function()
			return vim.api.nvim_buf_line_count(bufnr) == 4
		end, 10))
		assert.same({
			"methods",
			outer_indent .. "function addKey(obj, name, extractor)",
			body_indent,
			outer_indent .. "end",
		}, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
	end)
end)
