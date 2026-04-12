return {
	"shellRaining/hlchunk.nvim",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local ts = require("hlchunk.utils.ts_node_type")

		ts.tsx = {
			"jsx_element",
			"jsx_fragment",
			"jsx_self_closing_element",
			"function_declaration",
			"arrow_function",
			"class_declaration",
			"method_definition",
			"^if",
			"^for",
			"^while",
			"switch_statement",
			"try_statement",
			"catch_clause",
		}
		ts.typescript = ts.typescript or ts.tsx

		require("hlchunk").setup({
			indent = {
				enable = true,
				priority = 1,
				chars = {
					"│",
				},
			},
			chunk = {
				enable = false,
				priority = 100,
				notify = true,
				style = {},
				use_treesitter = true,
				chars = {
					horizontal_line = "─",
					vertical_line = "│",
					left_top = "┌",
					left_bottom = "└",
					right_arrow = ">",
				},
				textobject = "",
				max_file_size = 1024 * 1024,
				error_sign = true,
				duration = 0,
				delay = 0,
			},
			line_num = {
				enable = false,
			},
			blank = {
				enable = false,
			},
		})
	end,
}
