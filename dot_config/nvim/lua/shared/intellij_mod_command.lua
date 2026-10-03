local M = {}

-- Read serialized edits for preview; the original command still owns execution.
function M.text_updates(action)
	local command = action and (type(action.command) == "table" and action.command or action)
	if type(command) ~= "table" or command.command ~= "applyModCommand" then
		return nil
	end
	local files = {}
	local function collect(data)
		if type(data) ~= "table" or type(data.kind) ~= "string" then
			return false
		end
		if data.kind:match("%.Composite$") then
			for _, child in ipairs(data.commands or {}) do
				if not collect(child) then
					return false
				end
			end
			return true
		elseif data.kind:match("%.Navigate$") then
			return true
		elseif not data.kind:match("%.UpdateFileText$") then
			-- ponytail: preview text edits; interactive/unknown commands have no static diff.
			return false
		end
		if type(data.fileUrl) ~= "string" or type(data.oldText) ~= "string" or type(data.newText) ~= "string" then
			return false
		end
		local uri = data.fileUrl
		-- ModCommand uses file://C:/... on Windows, rather than an LSP file URI.
		if uri:match("^file://%a:/") then
			uri = vim.uri_from_fname(uri:sub(8))
		end
		local file = files[uri]
		if file and file.newText ~= data.oldText then
			return false
		end
		files[uri] = { uri = uri, oldText = file and file.oldText or data.oldText, newText = data.newText }
		return true
	end
	for _, data in ipairs(command.arguments or {}) do
		if not collect(data) then
			return nil
		end
	end
	return not vim.tbl_isempty(files) and vim.tbl_values(files) or nil
end

function M.preview(action)
	local files = M.text_updates(action)
	if not files then
		return nil
	end
	table.sort(files, function(a, b)
		return a.uri < b.uri
	end)
	local lines = {}
	for _, file in ipairs(files) do
		local diff = vim.diff(file.oldText, file.newText, { result_type = "unified", ctxlen = 3 })
		if diff ~= "" then
			if #lines > 0 then
				lines[#lines + 1] = ""
			end
			local name = vim.fn.fnamemodify(vim.uri_to_fname(file.uri), ":~:.")
			lines[#lines + 1], lines[#lines + 2] = "--- " .. name, "+++ " .. name
			vim.list_extend(lines, vim.split(diff, "\n", { trimempty = true }))
		end
	end
	return #lines > 0 and lines or { "No text changes" }
end

return M
