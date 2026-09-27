describe("Startup and file-open efficiency", function()
	it("keeps recent-file order and the eight-item limit without stat-ing other directories", function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/mini.starter")
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/mini.icons")
		local oldfiles, stat = vim.v.oldfiles, vim.uv.fs_stat
		local prefix = vim.fn.getcwd() .. package.config:sub(1, 1)
		local files = { "Z:/outside/project/ignored.rs", prefix .. "missing.rs", prefix .. "directory" }
		for i = 1, 10 do
			files[#files + 1] = prefix .. "file" .. i .. ".rs"
		end
		vim.v.oldfiles = files
		local calls = {}
		vim.uv.fs_stat = function(path)
			calls[#calls + 1] = path
			if path == prefix .. "missing.rs" then
				return nil
			end
			return { type = path == prefix .. "directory" and "directory" or "file" }
		end
		local ok, result = pcall(function()
			return require("plugins.mini-starter").opts().items[2]()
		end)
		vim.v.oldfiles, vim.uv.fs_stat = oldfiles, stat
		assert.is_true(ok)
		local names = vim.tbl_map(function(item)
			return item.name
		end, result)
		assert.same(
			{ "file1.rs", "file2.rs", "file3.rs", "file4.rs", "file5.rs", "file6.rs", "file7.rs", "file8.rs" },
			names
		)
		assert.are.equal(10, #calls)
		assert.is_nil(vim.tbl_contains(calls, files[1]) and true or nil)
	end)

	it("preserves package insertion for blank files and leaves existing code untouched", function()
		require("shared.java_kotlin_package").setup()
		local cases = {
			{ "" },
			{ " ", "\t", "" },
			{ "package existing;" },
			{ "// header", "class Example {}" },
			{ "", "", "class Example {}" },
		}
		for index, lines in ipairs(cases) do
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/src/main/java/sample/Case" .. index .. ".java")
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.api.nvim_exec_autocmds("BufEnter", { group = "JavaKotlinPackage", buffer = buf })
			local expected = index <= 2 and { "package sample", "" } or lines
			assert.same(expected, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end)

	it("does not fetch a whole Java buffer when its first line already contains code", function()
		require("shared.java_kotlin_package").setup()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. "/src/main/kotlin/sample/Large.kt")
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "package sample", "class Large" })
		local get_lines, reads = vim.api.nvim_buf_get_lines, {}
		vim.api.nvim_buf_get_lines = function(b, first, last, strict)
			if b == buf then
				reads[#reads + 1] = { first, last }
			end
			return get_lines(b, first, last, strict)
		end
		local ok, err = pcall(vim.api.nvim_exec_autocmds, "BufEnter", { group = "JavaKotlinPackage", buffer = buf })
		vim.api.nvim_buf_get_lines = get_lines
		vim.api.nvim_buf_delete(buf, { force = true })
		assert.is_true(ok, tostring(err))
		assert.same({ { 0, 1 } }, reads)
	end)

	it("uses the prepared kross bundle without starting a build", function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/kross.nvim")
		local kross = require("kross")
		kross.setup(require("plugins.kross").opts)
		local system, calls = vim.system, 0
		vim.system = function(...)
			calls = calls + 1
			error("unexpected editing-time build")
		end
		local ok, bundles = pcall(kross.bundles)
		vim.system = system
		assert.is_true(ok)
		assert.are.equal(0, calls)
		assert.are.equal(1, #bundles)
		assert.are.equal(1, vim.fn.filereadable(bundles[1]))
	end)
end)
