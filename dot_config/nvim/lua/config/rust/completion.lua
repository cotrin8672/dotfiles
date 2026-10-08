return function(ctx, items)
	if vim.bo[ctx.bufnr].filetype ~= "rust" then
		return items
	end

	for _, item in ipairs(items) do
		if item.client_name == "rust_analyzer" and item.label:match("^call_array%f[^%w_]") then
			local snippet = "call_array::<${1:2}>(${2:name}, ${3:inputs})$0"
			item.insertText = snippet
			item.insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet
			if item.textEdit then
				item.textEdit.newText = snippet
			end
		end
	end

	return items
end
