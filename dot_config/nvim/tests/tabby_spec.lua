describe("Tabby render cache", function()
	it("reuses renders until visible state changes", function()
		local data_root = vim.fn.stdpath("data") .. "/lazy/"
		vim.opt.runtimepath:append(data_root .. "tabby.nvim")
		vim.opt.runtimepath:append(data_root .. "mini.icons")

		package.loaded["plugins.tabby"] = nil
		require("plugins.tabby").config()

		local tabline = require("tabby.tabline")
		local tab_jumper = require("tabby.feature.tab_jumper")
		local original_render = tabline.render
		local calls = 0
		tabline.render = function()
			calls = calls + 1
			return ("render-%d"):format(calls)
		end

		vim.api.nvim_exec_autocmds("BufEnter", { group = "TabbyRenderCache", pattern = "*" })
		assert.are.equal("render-1", _G.TabbyRenderCached())
		assert.are.equal("render-1", _G.TabbyRenderCached())

		vim.api.nvim_exec_autocmds("BufModifiedSet", { group = "TabbyRenderCache", pattern = "*" })
		assert.are.equal("render-2", _G.TabbyRenderCached())

		tab_jumper.is_start = true
		assert.are.equal("render-3", _G.TabbyRenderCached())
		assert.are.equal("render-4", _G.TabbyRenderCached())

		tab_jumper.is_start = false
		tabline.render = original_render
	end)
end)
