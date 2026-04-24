local M = {}

M.entries = {}

function M.append(entry)
	if not entry.text or entry.text == "" then
		return
	end

	if not entry.severity then
		return
	end

	table.insert(M.entries, entry)
end

function M.clear()
	M.entries = {}
end

function M.get_entries()
	return M.entries
end

return M
