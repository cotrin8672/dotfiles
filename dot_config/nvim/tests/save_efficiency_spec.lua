describe("Save and lint ordering", function()
	local coordinator, calls, buffers, previous_lint
	before_each(function()
		previous_lint = package.loaded.lint
		calls, buffers = {}, {}
		package.loaded["config.lint"] = nil
		coordinator = require("config.lint")
		package.loaded.lint = {
			try_lint = function()
				calls[#calls + 1] = vim.api.nvim_get_current_buf()
			end,
		}
		for i = 1, 2 do
			buffers[i] = vim.api.nvim_create_buf(false, true)
		end
	end)
	after_each(function()
		vim.wait(10)
		package.loaded.lint = previous_lint
		for _, buf in ipairs(buffers) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end
	end)
	local function flush()
		vim.wait(10)
	end

	it("waits for formatting and lints its buffer once even after switching buffers", function()
		coordinator.after_save(buffers[1])
		local done = coordinator.format_started(buffers[1])
		coordinator.insert_leave(buffers[1])
		vim.api.nvim_set_current_buf(buffers[2])
		flush()
		assert.same({}, calls)
		done()
		flush()
		assert.same({ buffers[1] }, calls)
	end)
	it("coalesces synchronous formatter completion with either autocmd order", function()
		for _, order in ipairs({ "lint-first", "format-first" }) do
			calls = {}
			if order == "lint-first" then
				coordinator.after_save(buffers[1])
			end
			coordinator.format_started(buffers[1])()
			if order == "format-first" then
				coordinator.after_save(buffers[1])
			end
			flush()
			assert.same({ buffers[1] }, calls)
		end
	end)
	it("ignores a replaced format job and still lints when the newest formatter fails", function()
		local first = coordinator.format_started(buffers[1])
		local second = coordinator.format_started(buffers[1])
		first("cancelled")
		flush()
		assert.same({}, calls)
		second("formatter failed")
		flush()
		assert.same({ buffers[1] }, calls)
	end)
	it("retains lint on save without formatting and on InsertLeave", function()
		coordinator.after_save(buffers[1])
		flush()
		coordinator.insert_leave(buffers[2])
		assert.same(buffers, calls)
	end)
	it("keeps different buffers independent and ignores wiped buffers", function()
		coordinator.after_save(buffers[1])
		coordinator.after_save(buffers[2])
		vim.api.nvim_buf_delete(buffers[1], { force = true })
		flush()
		assert.same({ buffers[2] }, calls)
	end)
end)

describe("Conform save integration", function()
	it("lints the formatted file once after Conform's second write", function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/conform.nvim")
		local conform = require("conform")
		local complete, linted, previous_lint = nil, {}, package.loaded.lint
		local path = vim.fn.tempname() .. ".save-test"
		local buf = vim.api.nvim_create_buf(true, false)
		local other = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_current_buf(buf)
		vim.api.nvim_buf_set_name(buf, path)
		vim.bo[buf].filetype = "save_test"
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "before" })
		package.loaded.lint = {
			try_lint = function()
				linted[#linted + 1] = {
					buf = vim.api.nvim_get_current_buf(),
					disk = vim.fn.readfile(path),
				}
			end,
		}
		conform.setup({
			formatters_by_ft = { save_test = { "save_test" } },
			formatters = {
				save_test = {
					format = function(_, _, _, callback)
						complete = callback
					end,
				},
			},
			format_after_save = require("plugins.conform").opts.format_after_save,
		})
		local group = vim.api.nvim_create_augroup("SaveIntegrationTest", { clear = true })
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = group,
			callback = function(event)
				if not vim.b[event.buf].conform_applying_formatting then
					require("config.lint").after_save(event.buf)
				end
			end,
		})
		local ok, err = pcall(function()
			vim.cmd.write()
			vim.api.nvim_set_current_buf(other)
			vim.wait(10)
			assert.same({}, linted)
			assert.is_function(complete)
			complete(nil, { "after" })
			assert.is_true(vim.wait(1000, function()
				return #linted > 0
			end))
			assert.same({ { buf = buf, disk = { "after" } } }, linted)
			assert.are.equal(other, vim.api.nvim_get_current_buf())
			assert.is_false(vim.bo[buf].modified)
		end)
		vim.api.nvim_del_augroup_by_id(group)
		conform.setup({ format_after_save = false })
		package.loaded.lint = previous_lint
		vim.api.nvim_buf_delete(buf, { force = true })
		vim.api.nvim_buf_delete(other, { force = true })
		vim.fn.delete(path)
		assert(ok, err)
	end)
end)

describe("Rust check ownership", function()
	it("uses clippy through rust-analyzer and keeps other linters", function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/nvim-lint")
		package.loaded.lint = nil
		require("plugins.nvim-lint").config()
		local lint = require("lint")
		assert.is_nil(lint.linters_by_ft.rust)
		assert.same({ "clangtidy" }, lint.linters_by_ft.cpp)
		assert.same({ "eslint_d" }, lint.linters_by_ft.typescript)
		assert.are.equal("clippy", require("config.rust.lsp")["rust-analyzer"].check.command)
	end)
end)
