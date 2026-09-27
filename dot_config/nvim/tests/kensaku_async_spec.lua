describe("Kensaku asynchronous finder", function()
	local Async, ready, requests, originals, tasks, errors
	before_each(function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/snacks.nvim")
		Async = require("snacks.picker.util.async")
		ready, requests, tasks, errors = {}, {}, {}, {}
		originals = {
			vim.fn["denops#plugin#wait_async"],
			vim.fn["kensaku#query_async"],
			vim.g["denops#plugin#wait_timeout"],
		}
		vim.fn["denops#plugin#wait_async"] = function(_, callback)
			ready[#ready + 1] = callback
		end
		vim.fn["kensaku#query_async"] = function(pattern, success, opts)
			requests[#requests + 1] = { pattern = pattern, success = success, opts = opts }
		end
	end)
	after_each(function()
		for _, task in ipairs(tasks) do
			task:abort()
		end
		vim.wait(10)
		vim.fn["denops#plugin#wait_async"] = originals[1]
		vim.fn["kensaku#query_async"] = originals[2]
		vim.g["denops#plugin#wait_timeout"] = originals[3]
	end)
	local function start(pattern, results)
		local task = Async.new(function()
			results[#results + 1] = require("plugins.snacks-kensaku.query")(pattern)
		end)
		task:on("error", function(err)
			errors[#errors + 1] = err
		end)
		tasks[#tasks + 1] = task
		return task
	end
	it("leaves the main loop responsive while Denops and the query are pending", function()
		local results, tick = {}, false
		start("kensaku", results)
		vim.schedule(function()
			tick = true
		end)
		assert.is_true(vim.wait(1000, function()
			return #ready == 1 and tick
		end))
		assert.same({}, results)
		ready[1]()
		assert.are.equal("kensaku", requests[1].pattern)
		assert.same({}, results)
		requests[1].success("検索")
		assert.is_true(vim.wait(1000, function()
			return #results == 1
		end))
		assert.same({ "検索" }, results)
		assert.same({}, errors)
	end)
	it("discards old results when a new query replaces a running query", function()
		local results = {}
		local old = start("old", results)
		assert.is_true(vim.wait(1000, function()
			return #ready == 1
		end))
		ready[1]()
		old:abort()
		start("new", results)
		assert.is_true(vim.wait(1000, function()
			return #ready == 2
		end))
		ready[2]()
		requests[2].success("new result")
		requests[1].success("stale result")
		assert.is_true(vim.wait(1000, function()
			return #results == 1
		end))
		assert.same({ "new result" }, results)
	end)
	it("does not request a query after closing while Denops is starting", function()
		local task = start("closed", {})
		assert.is_true(vim.wait(1000, function()
			return #ready == 1
		end))
		task:abort()
		ready[1]()
		vim.wait(10)
		assert.same({}, requests)
	end)
	it("finishes with an error when the query fails or readiness times out", function()
		start("failure", {})
		assert.is_true(vim.wait(1000, function()
			return #ready == 1
		end))
		ready[1]()
		requests[1].opts.failure("query failed")
		assert.is_true(vim.wait(1000, function()
			return #errors == 1
		end))
		vim.g["denops#plugin#wait_timeout"] = 10
		start("timeout", {})
		assert.is_true(vim.wait(1000, function()
			return #errors == 2
		end))
		ready[2]()
		assert.are.equal(1, #requests)
	end)
end)
