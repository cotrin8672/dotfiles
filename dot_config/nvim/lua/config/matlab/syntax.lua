local M = {}
local contexts = {}

local block_keywords = {
	["if"] = true,
	["for"] = true,
	["while"] = true,
	["function"] = true,
	parfor = true,
	spmd = true,
	switch = true,
	try = true,
	classdef = true,
}
local class_sections = { properties = true, methods = true, events = true, enumeration = true }

function M.line(text, in_block_comment)
	local comment_depth = type(in_block_comment) == "number" and in_block_comment or (in_block_comment and 1 or 0)
	local opens_comment = text:match("^%s*%%{%s*$")
	if comment_depth > 0 or opens_comment then
		if opens_comment then
			comment_depth = comment_depth + 1
		elseif text:match("^%s*%%}%s*$") then
			comment_depth = comment_depth - 1
		end
		return {
			code = "",
			in_comment = true,
			in_block_comment = comment_depth > 0 and comment_depth or nil,
		}
	end

	local code, quote, index = {}, nil, 1
	while index <= #text do
		local character = text:sub(index, index)
		if quote then
			code[index] = " "
			if character == quote then
				if text:sub(index + 1, index + 1) == quote then
					index = index + 1
					code[index] = " "
				else
					quote = nil
				end
			end
		elseif character == "%" then
			return { code = table.concat(code), in_comment = true, comment_start = index }
		elseif text:sub(index, index + 2) == "..." then
			return { code = table.concat(code), continuation = true, in_comment = true, continuation_start = index }
		elseif character == '"' or character == "'" then
			local previous = text:sub(index - 1, index - 1)
			local transpose = character == "'"
				and index > 1
				and (previous:match("[%w_%)%]}']") or previous == "." or previous == '"')
			if transpose then
				code[index] = character
			else
				quote, code[index] = character, "x"
			end
		else
			code[index] = character
		end
		index = index + 1
	end
	return { code = table.concat(code), quote = quote }
end

function M.keyword(code)
	return code:match("^%s*([%a_][%w_]*)")
end

local function statements(code)
	local result, depth, start = {}, 0, 1
	for index = 1, #code do
		local character = code:sub(index, index)
		if character:match("[%(%[{]") then
			depth = depth + 1
		elseif character:match("[%)%]}]") then
			depth = depth - 1
		elseif depth == 0 and (character == ";" or character == ",") then
			table.insert(result, code:sub(start, index - 1))
			start = index + 1
		end
	end
	table.insert(result, code:sub(start))
	return result, depth
end

function M.depth(code)
	local _, depth = statements(code)
	return depth
end

local function delimiters(code, top, row)
	for index = 1, #code do
		local character = code:sub(index, index)
		if character:match("[%(%[{]") then
			top = { character = character, line = row, parent = top }
		elseif character:match("[%)%]}]") then
			top = top and top.parent
		end
	end
	return top
end

local function nested_function(bufnr, line_number, parent_line)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "matlab")
	if not ok or not parser then
		return nil
	end
	local trees = parser:parse(true)
	local text = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
	local col = (text:find("%S") or 1) - 1
	local node = trees[1]:root():descendant_for_range(line_number - 1, col, line_number - 1, col + 1)
	while node and node:type() ~= "function_definition" do
		node = node:parent()
	end
	if not node or node:range() ~= line_number - 1 then
		return nil
	end
	node = node:parent()
	while node do
		if node:type() == "function_definition" and node:range() == parent_line - 1 then
			return true
		end
		node = node:parent()
	end
	return false
end

function M.function_parent(bufnr, line_number, parent)
	while parent and parent.kind == "function" and vim.fn.indent(line_number) <= vim.fn.indent(parent.line) do
		-- A closing end below this header can change its parsed nesting.
		local cache = contexts[bufnr]
		cache.tree_row = math.min(cache.tree_row or line_number - 1, line_number - 1)
		if nested_function(bufnr, line_number, parent.line) then
			break
		end
		parent = parent.parent
	end
	return parent
end

local function advance(previous, text, line_number, bufnr)
	local line = M.line(text, previous.in_block_comment)
	local state = {
		top = previous.top,
		last_closed = previous.last_closed,
		in_block_comment = line.in_block_comment,
		branch = previous.branch,
	}
	local logical = previous.logical or { code = "", line = line_number }
	local code = logical.code .. " " .. line.code
	local parts, depth = statements(code)
	if line.continuation or depth > 0 then
		state.logical = {
			code = code,
			line = logical.line,
			depth = depth,
			delimiter = delimiters(line.code, logical.delimiter, line_number),
		}
		return state
	end

	for _, part in ipairs(parts) do
		part = vim.trim(part)
		local keyword = M.keyword(part)
		if part == "end" then
			local closed = state.top
			if closed then
				state.closed = state.closed or {}
				state.closed[closed] = true
			end
			state.top = closed and closed.parent
			if closed and state.branch and state.branch.block == closed then
				state.branch = state.branch.parent
			end
			state.last_closed = closed and closed.kind == "arguments" and { line = line_number } or nil
		elseif part ~= "" then
			state.last_closed = nil
			local parent = state.top and state.top.kind
			if (keyword == "case" or keyword == "otherwise") and parent == "switch" then
				if not state.branch or state.branch.block ~= state.top then
					state.branch = { block = state.top, parent = state.branch }
				end
			end
			local section = (class_sections[keyword] and parent == "classdef")
				or (keyword == "arguments" and parent == "function")
			local remainder = keyword and vim.trim(part:sub(#keyword + 1)) or ""
			local section_header = section and (remainder == "" or remainder:match("^%b()$"))
			if block_keywords[keyword] or section_header then
				if keyword == "function" then
					state.top = M.function_parent(bufnr, logical.line, state.top)
				end
				state.top = { kind = keyword, line = logical.line, parent = state.top }
				state.header = state.top
			end
		end
	end
	if state.header ~= state.top then
		state.header = nil
	end
	return state
end

function M.context(bufnr, line_count)
	local cache = contexts[bufnr]
	if not cache then
		cache = { valid = 0, states = { [0] = {} } }
		contexts[bufnr] = cache
		vim.api.nvim_buf_attach(bufnr, false, {
			on_lines = function(_, _, _, first)
				cache.valid = math.min(cache.valid, first, cache.tree_row or first)
				cache.tree_row = nil
			end,
			on_reload = function()
				cache.valid, cache.states, cache.tree_row = 0, { [0] = {} }, nil
			end,
			on_detach = function()
				contexts[bufnr] = nil
			end,
		})
	end
	if line_count > cache.valid then
		local state = cache.states[cache.valid]
		for index, text in ipairs(vim.api.nvim_buf_get_lines(bufnr, cache.valid, line_count, false)) do
			local row = cache.valid + index
			state = advance(state, text, row, bufnr)
			cache.states[row] = state
		end
		cache.valid = line_count
	end
	return cache.states[line_count]
end

function M.needs_end(bufnr, row)
	local header = M.context(bufnr, row).header
	if not header then
		return nil
	end
	local indentation = vim.fn.indent(header.line)
	for next_row = row + 1, vim.api.nvim_buf_line_count(bufnr) do
		local state = M.context(bufnr, next_row)
		local top = state.top
		local contains_header = false
		while top do
			if top == header then
				contains_header = true
				break
			end
			top = top.parent
		end
		if not contains_header then
			if vim.fn.indent(next_row) >= indentation then
				return nil
			end
			-- A less-indented end can belong to a parent whose end was borrowed
			-- by this new header. Already-balanced, unformatted blocks need none.
			local parent = header.parent
			local borrowed_indent, search_row = vim.fn.indent(next_row), next_row
			while parent do
				while parent and vim.fn.indent(parent.line) > borrowed_indent do
					parent = parent.parent
				end
				if not parent then
					return nil
				end
				local closing
				for closing_row = search_row, vim.api.nvim_buf_line_count(bufnr) do
					local following = M.context(bufnr, closing_row)
					if following.closed and following.closed[parent] then
						closing = closing_row
						break
					end
				end
				if not closing then
					return header
				end
				borrowed_indent, search_row = vim.fn.indent(closing), closing
				if borrowed_indent >= vim.fn.indent(parent.line) then
					return nil
				end
				parent = parent.parent
			end
			return nil
		end
	end
	return header
end

return M
