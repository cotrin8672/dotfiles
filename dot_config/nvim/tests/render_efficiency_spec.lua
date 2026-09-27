describe("Statusline content", function()
	local opts, previous, buf, root
	before_each(function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/lualine.nvim")
		previous = { lualine = package.loaded.lualine, status = vim.lsp.status }
		package.loaded.lualine = {
			setup = function(value)
				opts = value
			end,
		}
		vim.lsp.status = function()
			return "server"
		end
		require("plugins.lualine").config()
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)
		root = vim.fn.tempname()
		vim.fn.mkdir(root .. "/outer/.git", "p")
		vim.fn.mkdir(root .. "/outer/nested/src", "p")
	end)
	after_each(function()
		package.loaded.lualine = previous.lualine
		vim.lsp.status = previous.status
		vim.api.nvim_buf_delete(buf, { force = true })
		vim.fn.delete(root, "rf")
	end)
	it("keeps nearest Git roots including a worktree .git file and no repository", function()
		local component = opts.sections.lualine_b[1][1]
		vim.api.nvim_buf_set_name(buf, root .. "/outer/nested/src/a.rs")
		assert.are.equal("outer", component())
		vim.fn.writefile({ "gitdir: somewhere" }, root .. "/outer/nested/.git")
		vim.api.nvim_exec_autocmds("DirChanged", { pattern = "global" })
		assert.are.equal("nested", component())
		vim.api.nvim_buf_set_name(buf, root .. "/outside.txt")
		assert.are.equal("", component())
	end)
	it("keeps diagnostic counts and the existing severity priority through reset", function()
		local component = opts.sections.lualine_x[1][1]
		local ns = vim.api.nvim_create_namespace("RenderDiagnosticTest")
		local icons = require("ui.diagnostic_icons")
		local diagnostics = {}
		for _, level in ipairs({ 1, 2, 3, 4 }) do
			diagnostics[#diagnostics + 1] = { lnum = 0, col = 0, message = "test", severity = level }
		end
		for _, expected in ipairs({
			icons.error_icon .. "4",
			icons.warn_icon .. "3",
			icons.hint_icon .. "2",
			icons.hint_icon .. "1",
		}) do
			vim.diagnostic.set(ns, buf, diagnostics)
			assert.is_truthy(component():find(expected, 1, true))
			table.remove(diagnostics, 1)
		end
		vim.diagnostic.reset(ns, buf)
		assert.is_truthy(component():find("", 1, true))
	end)
end)

describe("Tabby icon cache", function()
	it("reuses both active colors without restatting paths and invalidates renames/themes", function()
		for _, plugin in ipairs({ "tabby.nvim", "mini.icons" }) do
			vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
		end
		package.loaded["plugins.tabby"] = nil
		require("plugins.tabby").config()
		local a = vim.api.nvim_create_buf(true, false)
		local b = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(a, vim.fn.tempname() .. ".rs")
		vim.api.nvim_buf_set_name(b, vim.fn.tempname() .. ".lua")
		local stat, calls = vim.fn.isdirectory, 0
		vim.fn.isdirectory = function(path)
			calls = calls + 1
			return stat(path)
		end
		local ok, err = pcall(function()
			local function render(buf)
				vim.api.nvim_set_current_buf(buf)
				return _G.TabbyRenderCached()
			end
			local first = render(a)
			render(b)
			local warm = calls
			assert.are.equal(first, render(a))
			render(b)
			assert.are.equal(warm, calls)
			vim.api.nvim_buf_set_name(a, vim.fn.tempname() .. ".m")
			render(a)
			assert.is_true(calls > warm)
			warm = calls
			vim.api.nvim_exec_autocmds("ColorScheme", { pattern = "default" })
			render(a)
			assert.is_true(calls > warm)
		end)
		vim.fn.isdirectory = stat
		vim.api.nvim_buf_delete(a, { force = true })
		vim.api.nvim_buf_delete(b, { force = true })
		assert(ok, err)
	end)
end)
