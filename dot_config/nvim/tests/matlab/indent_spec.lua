describe("MATLAB indentation", function()
	local bufnr

	before_each(function()
		vim.cmd("filetype indent on")
		vim.cmd("syntax enable")
		bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(bufnr)
		vim.cmd("setfiletype matlab")
		vim.bo[bufnr].indentexpr = "v:lua.require'config.matlab'.indent(v:lnum)"
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

	it("invalidates context after inserting, deleting, and replacing block boundaries", function()
		local indent = require("config.matlab").indent
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"function f()", "    arguments", "        x double", "    end", "    x = x + 1;", "end",
		})
		assert.are.equal(8, indent(3))
		assert.are.equal(4, indent(4))
		assert.are.equal(4, indent(5))
		vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "    if true" })
		assert.are.equal(4, indent(4))
		vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "    arguments", "        y double" })
		assert.are.equal(8, indent(4))
		assert.are.equal(4, indent(5))
		vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, {})
		assert.are.equal(0, indent(4))
	end)

	it("does not rescan the unchanged prefix for repeated or ascending indent requests", function()
		local lines = { "function f()", "    arguments" }
		for _ = 1, 500 do lines[#lines + 1] = "        x double" end
		lines[#lines + 1] = "    end"
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		local get_lines, read = vim.api.nvim_buf_get_lines, 0
		vim.api.nvim_buf_get_lines = function(buf, first, last, strict)
			local result = get_lines(buf, first, last, strict)
			read = read + #result
			return result
		end
		local ok, err = pcall(function()
			local indent = require("config.matlab").indent
			for row = 3, 502 do assert.are.equal(8, indent(row)) end
			assert.is_true(read < 1100)
			read = 0
			assert.are.equal(8, indent(400))
			assert.are.equal(1, read)
		end)
		vim.api.nvim_buf_get_lines = get_lines
		assert(ok, err)
	end)
end)
