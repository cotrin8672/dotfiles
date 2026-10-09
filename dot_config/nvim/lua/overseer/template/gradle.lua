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
		local errorformat = table.concat({
			"%Ee: %f:%l:%c %m",
			"%Ww: %f:%l:%c %m",
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
					local parser = { result_version = 0 }
					local compiler_output
					function parser:reset()
						compiler_output = require("overseer.parselib").parser_from_errorformat(errorformat)
						self.result_version = self.result_version + 1
					end
					function parser:parse(line)
						line = line:gsub("^([ew]: )(file://.-)(:%d+:%d+)", function(level, uri, position)
							return level .. vim.uri_to_fname(uri) .. position
						end)
						require("overseer.util").run_in_cwd(vim.fs.dirname(wrapper), function()
							compiler_output:parse(line)
						end)
						self.result_version = self.result_version + 1
					end
					function parser:get_result()
						return compiler_output:get_result()
					end
					parser:reset()
					return {
						name = "Gradle " .. params.task,
						cmd = { wrapper, params.task, "--console=plain" },
						cwd = vim.fs.dirname(wrapper),
						-- Windows ConPTY drops Gradle output; pipes retain the terminal's input forwarding.
						strategy = vim.fn.has("win32") == 1 and { "jobstart", wrap_opts = { pty = false } } or nil,
						components = {
							{ "on_output_parse", parser = parser },
							{ "on_result_diagnostics_quickfix", open = false, set_empty_results = true },
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
