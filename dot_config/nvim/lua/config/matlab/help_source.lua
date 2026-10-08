local M = {}

local function dedent(lines)
	while lines[1] and lines[1]:match("^%s*$") do
		table.remove(lines, 1)
	end
	while lines[#lines] and lines[#lines]:match("^%s*$") do
		table.remove(lines)
	end
	local prefix
	for _, line in ipairs(lines) do
		if not line:match("^%s*$") then
			local indent = line:match("^%s*")
			prefix = prefix or indent
			while indent:sub(1, #prefix) ~= prefix do
				prefix = prefix:sub(1, -2)
			end
		end
	end
	for i, line in ipairs(lines) do
		lines[i] = line:sub(#(prefix or "") + 1)
	end
	return lines
end

local function span(lines, first, last)
	local sr, sc = first:range()
	local _, _, er, ec = (last or first):range()
	local result = {}
	for row = sr, er do
		local line = lines[row + 1]
		local tail = line:sub(ec + 1)
		if row == er and not (tail:match("^%s*$") or tail:match("^%s*%%")) then
			line = line:sub(1, ec)
		end
		if row == sr and not line:sub(1, sc):match("^%s*$") then
			line = line:sub(sc + 1)
		end
		table.insert(result, line)
	end
	return dedent(result)
end

local function declaration(node)
	local name = node:field("name")[1]
	if not name or name:has_error() then
		return nil
	end
	local last = name
	local continuation
	for child in node:iter_children() do
		local kind = child:type()
		if kind == "function_arguments" then
			last = child
		end
		if
			kind == "\n"
			or kind == ","
			or kind == ";"
			or kind == "block"
			or kind == "arguments_statement"
			or kind == "comment"
			or kind == "end"
		then
			break
		end
		if child:has_error() or child:missing() then
			return nil
		end
		continuation = kind == "line_continuation"
	end
	if continuation then
		return nil
	end
	return last
end

local function candidates(root, source)
	local result = {}
	local function visit(node, class)
		if node:type() == "class_definition" then
			local name = node:field("name")[1]
			class = name and { name = vim.treesitter.get_node_text(name, source), node = node } or nil
		elseif node:type() == "function_definition" then
			local name = node:field("name")[1]
			if name then
				local prefix = ""
				for child in node:iter_children() do
					if child:type() == "get." or child:type() == "set." then
						prefix = child:type()
					end
				end
				table.insert(result, {
					node = node,
					name = vim.treesitter.get_node_text(name, source),
					prefix = prefix,
					class = class,
					method = node:parent():type() == "methods",
				})
			end
		end
		for child in node:iter_children() do
			visit(child, class)
		end
	end
	visit(root)
	return result
end

local function matches(candidate, symbol, row)
	local name = candidate.prefix .. candidate.name
	if symbol ~= name and symbol:sub(-#name - 1) ~= "." .. name then
		if candidate.prefix == "" or symbol:match("[gs]et%.[^.]+$") or symbol:match("([^.]+)$") ~= candidate.name then
			return false
		end
		name = candidate.name
	end
	if
		row == nil
		and candidate.method
		and candidate.class
		and candidate.name ~= candidate.class.name
		and symbol ~= name
	then
		local qualifier = symbol:sub(1, -#name - 2):match("([^.]+)$")
		return qualifier == candidate.class.name
	end
	return true
end

local function select_function(nodes, symbol, row)
	local selected
	for _, candidate in ipairs(nodes) do
		if matches(candidate, symbol, row) then
			local sr, _, er = candidate.node:range()
			local constructor_row = candidate.class
				and candidate.name == candidate.class.name
				and row == candidate.class.node:start()
			if row == nil or (row >= sr and row <= er) or constructor_row then
				if selected then
					local previous = selected.node:start()
					if row == nil or sr == previous then
						return nil
					end
					if sr > previous then
						selected = candidate
					end
				else
					selected = candidate
				end
			end
		end
	end
	return selected and selected.node
end

function M.extract(source, symbol, row)
	if type(source) ~= "string" or source == "" or type(symbol) ~= "string" or symbol == "" then
		return nil
	end
	if row ~= nil and (type(row) ~= "number" or row < 0 or row % 1 ~= 0) then
		return nil
	end
	source = source:gsub("\r\n", "\n"):gsub("\r", "\n")
	local ok, parser = pcall(vim.treesitter.get_string_parser, source, "matlab")
	if not ok then
		return nil
	end
	local parsed, trees = pcall(parser.parse, parser)
	if not parsed or not trees[1] then
		return nil
	end
	local node = select_function(candidates(trees[1]:root(), source), symbol, row)
	local last = node and declaration(node)
	if not last then
		return nil
	end
	local lines = vim.split(source, "\n", { plain = true })
	local _, _, header_row = last:range()
	local result = { signature = span(lines, node, last), arguments = {}, help = {} }
	local body_or_end
	for child in node:iter_children() do
		local kind = child:type()
		if kind == "block" or kind == "end" then
			body_or_end = true
			break
		elseif kind == "ERROR" then
			if child:child(0) and child:child(0):type() == "arguments" then
				return nil
			end
			body_or_end = true
			break
		elseif kind == "line_continuation" and child:start() > header_row then
			body_or_end = true
			break
		elseif kind == "arguments_statement" then
			if child:has_error() then
				return nil
			end
			local ending
			for token in child:iter_children() do
				if token:type() == "end" and not token:missing() then
					ending = token
				end
			end
			if not ending then
				return nil
			end
			if #result.arguments > 0 then
				table.insert(result.arguments, "")
			end
			vim.list_extend(result.arguments, span(lines, child, ending))
		elseif kind == "comment" then
			local sr, _, er = child:range()
			local help = {}
			for comment_row = math.max(sr, header_row + 1), er do
				local text = lines[comment_row + 1]
				if not text:match("^%s*%%[{}]%s*$") then
					table.insert(help, (text:gsub("^%s*%% ?", "")))
				end
			end
			help = dedent(help)
			if #result.help > 0 and #help > 0 then
				table.insert(result.help, "")
			end
			vim.list_extend(result.help, help)
		end
	end
	-- Recovery can put an unfinished arguments block just outside the function.
	local sibling = not body_or_end and node:next_named_sibling()
	if sibling and sibling:type() == "ERROR" and sibling:child(0) and sibling:child(0):type() == "arguments" then
		return nil
	end
	return result
end

return M
