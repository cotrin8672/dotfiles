-- Called from a Snacks finder coroutine; only Denops callbacks run on the main loop.
return function(pattern)
	local async = assert(require("snacks.picker.util.async").running())
	local done, result, failure = false, nil, nil
	local timer
	local function finish(value, err)
		if done or async:aborted() then
			return
		end
		done, result, failure = true, value, err
		async:resume()
	end

	vim.schedule(function()
		if async:aborted() then
			return
		end
		timer = vim.defer_fn(function()
			finish(nil, "Timed out waiting for Kensaku")
		end, vim.g["denops#plugin#wait_timeout"] or 30000)
		async:on("done", function()
			if not timer:is_closing() then
				timer:stop()
				timer:close()
			end
		end)
		vim.fn["denops#plugin#wait_async"]("kensaku", function()
			if done or async:aborted() then
				return
			end
			timer:stop()
			timer:close()
			local ok, err = pcall(vim.fn["kensaku#query_async"], pattern, function(value)
				finish(value)
			end, {
				rxop = vim.g["kensaku#rxop#javascript"],
				failure = function(err)
					finish(nil, err)
				end,
			})
			if not ok then
				finish(nil, err)
			end
		end)
	end)
	while not done do
		async:suspend()
	end
	if failure then
		error(failure)
	end
	return result
end
