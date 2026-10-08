local function find_wrapper(opts)
	local filename = vim.fn.has("win32") == 1 and "gradlew.bat" or "gradlew"
	return vim.fs.find(filename, { path = opts.dir, upward = true, type = "file" })[1]
end

return {
	cache_key = find_wrapper,
	generator = function(opts, cb)
		local wrapper = find_wrapper(opts)
		if not wrapper then
			return "No Gradle wrapper found"
		end
		local uri_prefix = vim.fn.has("win32") == 1 and "file:///" or "file://"
		local errorformat = table.concat({
			"%Ee: " .. uri_prefix .. "%f:%l:%c %m",
			"%Ww: " .. uri_prefix .. "%f:%l:%c %m",
			"%Ee: %f: (%l\\, %c): %m",
			"%Ww: %f: (%l\\, %c): %m",
			vim.o.errorformat,
		}, ",")
		cb({
			{
				name = "Gradle wrapper",
				params = {
					task = {
						type = "string",
						default = "classes",
						desc = "Task (e.g. classes, runClient, runServer, runData)",
					},
				},
				builder = function(params)
					return {
						name = "Gradle " .. params.task,
						cmd = { wrapper, params.task, "--console=plain" },
						cwd = vim.fs.dirname(wrapper),
						components = {
							-- ponytail: errorformat cannot decode escaped compiler URI paths; use an output parser if needed.
							{ "on_output_quickfix", errorformat = errorformat, open = false, items_only = true },
							{
								"unique",
								replace = false,
								restart_interrupts = false,
								compare = function(a, b)
									return a.name == b.name and a.cwd == b.cwd
								end,
							},
							"default",
						},
					}
				end,
			},
		})
	end,
}
