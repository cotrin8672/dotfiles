describe("MATLAB indentation", function()
	local bufnr

	before_each(function()
		vim.cmd("filetype indent on")
		vim.cmd("syntax enable")
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(bufnr)
		vim.cmd("setfiletype matlab")
		vim.bo[bufnr].expandtab = true
		vim.bo[bufnr].shiftwidth = 4
		vim.bo[bufnr].tabstop = 4
		vim.wait(50)
	end)

	after_each(function()
		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
	end)

	it("indents arguments blocks and their closing end", function()
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"classdef Scheme",
			"properties (SetAccess = private)",
			"id (1, 1) string",
			"end",
			"function obj = Scheme(id, values)",
			"arguments",
			"id (1, 1) string",
			"end",
			"",
			"obj.id = id;",
			"end",
		})

		vim.cmd("normal! gg=G")

		assert.same({
			"classdef Scheme",
			"    properties (SetAccess = private)",
			"        id (1, 1) string",
			"    end",
			"    function obj = Scheme(id, values)",
			"        arguments",
			"            id (1, 1) string",
			"        end",
			"",
			"        obj.id = id;",
			"    end",
		}, vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
	end)
end)
