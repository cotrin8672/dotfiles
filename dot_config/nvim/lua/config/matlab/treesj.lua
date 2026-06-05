local M = {}

local function strip_continuation(line)
	return (line:gsub("%s*%.%.%.%s*$", ""))
end

local function add_continuations(lines)
	local formatted = {}

	for index, line in ipairs(lines) do
		line = strip_continuation(line)

		if index < #lines and line:find("%S") then
			line = line .. " ..."
		end

		formatted[index] = line
	end

	return formatted
end

local function remove_continuations(lines)
	return vim.tbl_map(strip_continuation, lines)
end

function M.langs()
	local lang_utils = require("treesj.langs.utils")

	local matlab_args = lang_utils.set_preset_for_args({
		split = {
			format_resulted_lines = add_continuations,
		},
		join = {
			format_resulted_lines = remove_continuations,
		},
	})

	local matlab_list = lang_utils.set_preset_for_list({
		split = {
			format_resulted_lines = add_continuations,
		},
		join = {
			space_in_brackets = false,
			format_resulted_lines = remove_continuations,
		},
	})

	return {
		matlab = {
			arguments = matlab_args,
			function_arguments = matlab_args,
			multioutput_variable = matlab_args,
			superclasses = matlab_args,
			validation_functions = matlab_args,
			dimensions = matlab_args,
			attributes = matlab_args,
			matrix = matlab_list,
			cell = matlab_list,
			function_call = {
				target_nodes = { "arguments" },
			},
			function_definition = {
				target_nodes = { "function_arguments", "multioutput_variable" },
			},
			function_signature = {
				target_nodes = { "function_arguments" },
			},
			lambda = {
				target_nodes = { "arguments" },
			},
			class_definition = {
				target_nodes = { "superclasses" },
			},
			property = {
				target_nodes = { "validation_functions", "dimensions", "attributes" },
			},
			assignment = {
				target_nodes = {
					"arguments",
					"function_arguments",
					"multioutput_variable",
					"matrix",
					"cell",
					"validation_functions",
					"dimensions",
					"attributes",
				},
			},
		},
	}
end

return M
