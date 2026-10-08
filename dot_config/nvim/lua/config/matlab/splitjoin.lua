local M = {}

local namespace = vim.api.nvim_create_namespace("MatlabSplitJoin")
local states = {}

vim.api.nvim_create_autocmd("BufWipeout", {
	group = vim.api.nvim_create_augroup("MatlabSplitJoinState", { clear = true }),
	callback = function(event)
		states[event.buf] = nil
	end,
})

local list_types = {
	arguments = { open = "(", close = ")", separator = "," },
	function_arguments = { open = "(", close = ")", separator = "," },
	multioutput_variable = { open = "[", close = "]", separator = "," },
	attributes = { open = "(", close = ")", separator = "," },
	dimensions = { open = "(", close = ")", separator = "," },
	validation_functions = { open = "{", close = "}", separator = "," },
	range = { open = "", close = "", separator = ":" },
}

local container_types = vim.tbl_extend("force", {}, list_types, {
	superclasses = true,
	matrix = true,
	cell = true,
})

local wrapper_targets = {
	function_call = "arguments",
	function_definition = "function_arguments",
	lambda = "arguments",
}

local operator_groups = {
	["||"] = "logical_or",
	["|"] = "logical_or",
	["&&"] = "logical_and",
	["&"] = "logical_and",
	["=="] = "comparison",
	["~="] = "comparison",
	["<"] = "comparison",
	["<="] = "comparison",
	[">"] = "comparison",
	[">="] = "comparison",
	[":"] = "range",
	["+"] = "additive",
	["-"] = "additive",
	["*"] = "multiplicative",
	["/"] = "multiplicative",
	["\\"] = "multiplicative",
	[".*"] = "multiplicative",
	["./"] = "multiplicative",
	[".\\"] = "multiplicative",
	["^"] = "power",
	[".^"] = "power",
}

local operator_node_types = {
	binary_operator = true,
	boolean_operator = true,
	comparison_operator = true,
}

local function notify(message)
	vim.notify(message, vim.log.levels.INFO, { title = "MATLAB Split/Join" })
end

local function node_text(node, bufnr)
	return vim.treesitter.get_node_text(node, bufnr)
end

local function get_text(bufnr, start_row, start_col, end_row, end_col)
	return table.concat(vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {}), "\n")
end

local function text_between(bufnr, left, right)
	local _, _, left_row, left_col = left:range()
	local right_row, right_col = right:range()
	return get_text(bufnr, left_row, left_col, right_row, right_col)
end

local function direct_named_children(node)
	local children = {}
	for child in node:iter_children() do
		if child:named() and child:type() ~= "line_continuation" and child:type() ~= "comment" then
			table.insert(children, child)
		end
	end
	return children
end

local function direct_operator(node)
	for child in node:iter_children() do
		if not child:named() and child:type() ~= "line_continuation" then
			local operator = child:type()
			if operator_groups[operator] then
				return operator
			end
		end
	end
end

local function has_blocking_syntax(node, bufnr)
	if node:missing() or node:type() == "ERROR" or node:type() == "comment" then
		return true
	end

	if node:type() == "line_continuation" and not node_text(node, bufnr):match("^%.%.%.%s*$") then
		return true
	end

	for child in node:iter_children() do
		if has_blocking_syntax(child, bufnr) then
			return true
		end
	end

	return false
end

local function node_at_cursor(bufnr)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local line = assert(vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1])
	local col = math.min(cursor[2], math.max(#line - 1, 0))
	return vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
end

local function separate_arguments(node)
	return node:type() == "function_arguments"
		or (node:type() == "arguments" and node:parent():type() == "function_call")
end

local function container_has_multiple_items(node)
	if node:type() ~= "matrix" and node:type() ~= "cell" then
		return #direct_named_children(node) >= (separate_arguments(node) and 1 or 2)
	end

	local count = 0
	for child in node:iter_children() do
		if child:named() and child:type() == "row" then
			count = count + #direct_named_children(child)
			if count >= 2 then
				return true
			end
		end
	end
	return false
end

local function wrapped_target(node)
	local target_type = wrapper_targets[node:type()]
	if not target_type then
		return nil
	end

	for child in node:iter_children() do
		if child:named() and child:type() == target_type and container_has_multiple_items(child) then
			return child
		end
	end
end

local function target_range(node)
	if node:type() == "arguments" then
		local opening, closing
		for child in node:parent():iter_children() do
			if child:type() == "(" then
				opening = child
			elseif child:type() == ")" then
				closing = child
			end
		end
		if opening and closing then
			local start_row, start_col = opening:range()
			local _, _, end_row, end_col = closing:range()
			return start_row, start_col, end_row, end_col
		end
	end
	return node:range()
end

local function target_contains_row(node, row)
	local start_row, _, end_row, end_col = target_range(node)
	return row >= start_row and (row < end_row or (row == end_row and end_col > 0))
end

local function target_is_split(node, bufnr, original)
	if not separate_arguments(node) and not operator_node_types[node:type()] then
		return original:find("\n", 1, true) ~= nil
	end

	local row, col, end_row, end_col = target_range(node)
	for _, child in ipairs(direct_named_children(node)) do
		local child_row, child_col, child_end_row, child_end_col = child:range()
		if get_text(bufnr, row, col, child_row, child_col):find("\n", 1, true) then
			return true
		end
		row, col = child_end_row, child_end_col
	end
	return get_text(bufnr, row, col, end_row, end_col):find("\n", 1, true) ~= nil
end

local function target_from_node(node, row)
	local binary_target
	while node do
		if node:type() == "parenthesis" then
			local grouped = node
			repeat
				grouped = direct_named_children(grouped)[1]
			until not grouped or grouped:type() ~= "parenthesis"
			if grouped then
				if
					operator_node_types[grouped:type()]
					or (container_types[grouped:type()] and container_has_multiple_items(grouped))
				then
					return grouped
				end
				return wrapped_target(grouped)
			end
			return nil
		end
		if container_types[node:type()] and container_has_multiple_items(node) and target_contains_row(node, row) then
			return node
		end
		local wrapped = wrapped_target(node)
		if wrapped and target_contains_row(wrapped, row) then
			return wrapped
		end
		if operator_node_types[node:type()] and target_contains_row(node, row) then
			binary_target = node
		end
		node = node:parent()
	end

	if binary_target then
		return binary_target
	end
	return nil
end

local function find_target(bufnr)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "matlab")
	if not ok or not parser then
		notify("MATLAB Tree-sitter parser is unavailable. Run :TSInstall matlab.")
		return nil
	end
	parser:parse(true)

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, cursor_col = cursor[1] - 1, cursor[2]
	local target = target_from_node(node_at_cursor(bufnr), row)
	if target then
		return target
	end

	local line = assert(vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1])
	if line == "" then
		return nil, "No supported MATLAB expression on the cursor line"
	end

	local max_col = #line - 1
	local origin = math.min(cursor_col, max_col)
	local visited = {}
	for distance = 0, max_col do
		for _, col in ipairs({ origin - distance, origin + distance }) do
			if col >= 0 and col <= max_col and not visited[col] then
				visited[col] = true
				local node = vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } })
				target = node and target_from_node(node, row) or nil
				if target then
					return target
				end
			end
		end
	end

	return nil, "No supported MATLAB expression at the cursor"
end

local function continuation_indent(bufnr, start_row)
	local line = assert(vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1])
	local base = line:match("^%s*") or ""
	local width = vim.bo[bufnr].shiftwidth
	if width == 0 then
		width = vim.bo[bufnr].tabstop
	end
	return base .. string.rep(" ", width), base
end

local function render_parts(open, close, items, separators, indent, split, base)
	if #items < (base and 1 or 2) then
		return nil
	end

	if not split then
		local pieces = { open, items[1] }
		for index, separator in ipairs(separators) do
			local spacing = separator == " " and "" or " "
			table.insert(pieces, separator .. spacing)
			table.insert(pieces, items[index + 1])
		end
		table.insert(pieces, close)
		return table.concat(pieces), #open
	end

	local function split_suffix(separator)
		return separator == " " and " ..." or separator .. " ..."
	end

	if base then
		local lines = { open .. " ..." }
		for index, item in ipairs(items) do
			table.insert(lines, indent .. item .. (index < #items and split_suffix(separators[index]) or " ..."))
		end
		table.insert(lines, base .. close)
		return table.concat(lines, "\n"), #indent, 1
	end

	local lines = { open .. items[1] .. split_suffix(separators[1]) }
	for index = 2, #items do
		local suffix = ""
		if index < #items then
			suffix = split_suffix(separators[index])
		end
		table.insert(lines, indent .. items[index] .. suffix)
	end
	lines[#lines] = lines[#lines] .. close
	return table.concat(lines, "\n"), #open
end

local function format_list(node, bufnr, split)
	local config = list_types[node:type()]
	local children = direct_named_children(node)
	if #children < (separate_arguments(node) and 1 or 2) then
		return nil
	end

	local items = {}
	local separators = {}
	local start_row = target_range(node)
	local indent, base = continuation_indent(bufnr, start_row)
	local item_indent = split and separate_arguments(node) and indent or base
	for index, child in ipairs(children) do
		local row = child:range()
		local item = node_text(child, bufnr)
		local shift = vim.fn.strdisplaywidth(item_indent) - vim.fn.indent(row + 1)
		if shift ~= 0 then
			item = item:gsub("\n([ \t]*)", function(leading)
				return "\n" .. string.rep(" ", math.max(0, vim.fn.strdisplaywidth(leading) + shift))
			end)
		end
		table.insert(items, item)
		item_indent = split and indent or (item:match("\n([ \t]*)[^\n]*$") or item_indent)
		if index < #children then
			local gap = text_between(bufnr, child, children[index + 1])
			if not gap:find(config.separator, 1, true) then
				return nil
			end
			table.insert(separators, config.separator)
		end
	end

	local formatted, cursor_col, cursor_row = render_parts(
		config.open,
		config.close,
		items,
		separators,
		indent,
		split,
		separate_arguments(node) and base or nil
	)
	if separate_arguments(node) then
		local row, col = children[1]:range()
		local first_target = target_from_node(vim.treesitter.get_node({ bufnr = bufnr, pos = { row, col } }), row)
		if first_target and not vim.deep_equal({ target_range(first_target) }, { target_range(node) }) then
			-- Keep a repeated toggle on this call when its first argument has its own target.
			return formatted, 0, 0
		end
	end
	return formatted, cursor_col, cursor_row
end

local function matrix_parts(node, bufnr)
	local rows = {}
	for child in node:iter_children() do
		if child:named() and child:type() == "row" then
			table.insert(rows, child)
		end
	end

	local items = {}
	local separators = {}
	for row_index, row in ipairs(rows) do
		local elements = direct_named_children(row)
		for element_index, element in ipairs(elements) do
			table.insert(items, node_text(element, bufnr))
			if element_index < #elements then
				local gap = text_between(bufnr, element, elements[element_index + 1])
				table.insert(separators, gap:find(",", 1, true) and "," or " ")
			elseif row_index < #rows then
				table.insert(separators, ";")
			end
		end
	end

	return items, separators
end

local function format_matrix(node, bufnr, split)
	local items, separators = matrix_parts(node, bufnr)
	local start_row = node:range()
	local open = node:type() == "matrix" and "[" or "{"
	local close = node:type() == "matrix" and "]" or "}"
	return render_parts(open, close, items, separators, continuation_indent(bufnr, start_row), split)
end

local function format_superclasses(node, bufnr, split)
	local children = direct_named_children(node)
	if #children < 2 then
		return nil
	end

	local items = {}
	local separators = {}
	for index, child in ipairs(children) do
		table.insert(items, node_text(child, bufnr))
		if index < #children then
			local gap = text_between(bufnr, child, children[index + 1])
			if not gap:find("&", 1, true) then
				return nil
			end
			table.insert(separators, " &")
		end
	end

	local start_row = node:range()
	return render_parts("< ", "", items, separators, continuation_indent(bufnr, start_row), split)
end

local function flatten_binary(node, bufnr, group, items, operators)
	if not operator_node_types[node:type()] then
		table.insert(items, node_text(node, bufnr))
		return true
	end

	local operator = direct_operator(node)
	local children = direct_named_children(node)
	if not operator or #children ~= 2 then
		return false
	end

	if operator_groups[operator] ~= group then
		table.insert(items, node_text(node, bufnr))
		return true
	end

	if not flatten_binary(children[1], bufnr, group, items, operators) then
		return false
	end
	table.insert(operators, operator)
	return flatten_binary(children[2], bufnr, group, items, operators)
end

local function format_binary(node, bufnr, split)
	local operator = direct_operator(node)
	if not operator then
		return nil
	end

	local items = {}
	local operators = {}
	if not flatten_binary(node, bufnr, operator_groups[operator], items, operators) or #items < 2 then
		return nil
	end

	local separators = vim.tbl_map(function(item)
		return " " .. item
	end, operators)

	local start_row, start_col = node:range()
	local formatted, cursor_col = render_parts("", "", items, separators, continuation_indent(bufnr, start_row), split)
	local first_target =
		target_from_node(vim.treesitter.get_node({ bufnr = bufnr, pos = { start_row, start_col } }), start_row)
	if first_target and not vim.deep_equal({ target_range(first_target) }, { target_range(node) }) then
		local lines = vim.split(items[1], "\n", { plain = true })
		return formatted, #lines[#lines] + 1, #lines - 1
	end
	return formatted, cursor_col
end

local function format_target(node, bufnr, split)
	if list_types[node:type()] then
		return format_list(node, bufnr, split)
	end
	if node:type() == "matrix" or node:type() == "cell" then
		return format_matrix(node, bufnr, split)
	end
	if node:type() == "superclasses" then
		return format_superclasses(node, bufnr, split)
	end
	if operator_node_types[node:type()] then
		return format_binary(node, bufnr, split)
	end
end

local function relative_cursor(bufnr, start_row, start_col)
	assert(vim.api.nvim_win_get_buf(0) == bufnr, "MATLAB split/join buffer is not in the current window")
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	return { row - start_row, row == start_row and cursor[2] - start_col or cursor[2] }
end

local function text_end(start_row, start_col, text)
	local lines = vim.split(text, "\n", { plain = true })
	if #lines == 1 then
		return start_row, start_col + #lines[1]
	end
	return start_row + #lines - 1, #lines[#lines]
end

local function set_cursor(bufnr, start_row, start_col, relative)
	assert(vim.api.nvim_win_get_buf(0) == bufnr, "MATLAB split/join buffer is not in the current window")

	local row = start_row + relative[1]
	local col = relative[1] == 0 and start_col + relative[2] or relative[2]
	local line = assert(vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1])
	vim.api.nvim_win_set_cursor(0, { row + 1, math.min(math.max(col, 0), #line) })
end

local function set_mark(bufnr, state, start_row, start_col, text)
	local end_row, end_col = text_end(start_row, start_col, text)
	state.mark = vim.api.nvim_buf_set_extmark(bufnr, namespace, start_row, start_col, {
		end_row = end_row,
		end_col = end_col,
		right_gravity = false,
		end_right_gravity = true,
	})
end

local function replace_state(bufnr, state, target_index, start_row, start_col, end_row, end_col)
	local target = state.forms[target_index]
	if state.mark then
		vim.api.nvim_buf_del_extmark(bufnr, namespace, state.mark)
	end
	vim.api.nvim_buf_set_text(
		bufnr,
		start_row,
		start_col,
		end_row,
		end_col,
		vim.split(target.text, "\n", { plain = true })
	)
	state.current = target_index
	set_mark(bufnr, state, start_row, start_col, target.text)
	set_cursor(bufnr, start_row, start_col, target.cursor)
end

local function remove_state(bufnr, state)
	if state.mark then
		vim.api.nvim_buf_del_extmark(bufnr, namespace, state.mark)
	end
	for index, candidate in ipairs(states[bufnr] or {}) do
		if candidate == state then
			table.remove(states[bufnr], index)
			return
		end
	end
end

local function state_for_target(bufnr, node)
	local range = { target_range(node) }
	for _, state in ipairs(vim.list_slice(states[bufnr] or {})) do
		local mark = vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, state.mark, { details = true })
		if #mark == 0 then
			remove_state(bufnr, state)
		else
			local details = mark[3]
			if vim.deep_equal(range, { mark[1], mark[2], details.end_row, details.end_col }) then
				return state, mark[1], mark[2], details.end_row, details.end_col
			end
		end
	end
end

local function toggle_saved_state(bufnr, node)
	while true do
		local state, start_row, start_col, end_row, end_col = state_for_target(bufnr, node)
		if not state then
			return false
		end

		local current = get_text(bufnr, start_row, start_col, end_row, end_col)
		if current == state.forms[state.current].text then
			local target_index = state.current == 1 and 2 or 1
			replace_state(bufnr, state, target_index, start_row, start_col, end_row, end_col)
			return true
		end
		remove_state(bufnr, state)
	end
end

function M.toggle(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	assert(vim.api.nvim_buf_is_valid(bufnr), "MATLAB split/join buffer is invalid")
	assert(vim.api.nvim_get_current_buf() == bufnr, "MATLAB split/join buffer is not current")
	states[bufnr] = states[bufnr] or {}

	local node = find_target(bufnr)
	if not node then
		return false
	end
	if toggle_saved_state(bufnr, node) then
		return true
	end
	if has_blocking_syntax(node:type() == "arguments" and node:parent() or node, bufnr) then
		notify("The selected MATLAB expression contains a comment or syntax error")
		return false
	end

	local start_row, start_col, end_row, end_col = target_range(node)
	local original = get_text(bufnr, start_row, start_col, end_row, end_col)
	local is_split = target_is_split(node, bufnr, original)
	local formatted, generated_cursor_col, generated_cursor_row = format_target(node, bufnr, not is_split)
	if not formatted or formatted == original then
		notify(
			is_split and "The selected MATLAB expression cannot be joined"
				or "The selected MATLAB expression cannot be split"
		)
		return false
	end

	local original_cursor = relative_cursor(bufnr, start_row, start_col)
	if is_split then
		-- Re-splitting a joined expression uses the canonical layout, including existing manual wrapping.
		local canonical, cursor_col, cursor_row = format_target(node, bufnr, true)
		if canonical ~= original then
			original = assert(canonical)
			original_cursor = { cursor_row or 0, assert(cursor_col) }
		end
	end

	local state = {
		forms = {
			{ text = original, cursor = original_cursor },
			{ text = formatted, cursor = { generated_cursor_row or 0, assert(generated_cursor_col) } },
		},
		current = 1,
	}
	table.insert(states[bufnr], state)
	replace_state(bufnr, state, 2, start_row, start_col, end_row, end_col)
	return true
end

return M
