local core = require("config.matlab.core")

vim.api.nvim_create_user_command("MatlabClientInfo", function()
	local client = core.get_client(0)

	if not client then
		vim.notify("matlab_ls client not found", vim.log.levels.ERROR)
		return
	end

	vim.notify(vim.inspect({
		id = client.id,
		name = client.name,
	}))
end, {})

vim.api.nvim_create_user_command("MatlabDocumentSymbols", function()
	local bufnr = vim.api.nvim_get_current_buf()

	local params = {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
	}
	local _, err = core.request("textDocument/documentSymbol", params, function(request_err, result)
		if request_err then
			vim.notify("request error: " .. vim.inspect(request_err), vim.log.levels.ERROR)
			return
		end

		if not result or vim.tbl_isempty(result) then
			vim.notify("no symbols found", vim.log.levels.WARN)
		end

		local names = {}
		for _, symbol in ipairs(result) do
			table.insert(names, symbol.name)
		end

		vim.notify("symbols: \n" .. table.concat(names, "\n"))
	end, bufnr)

	if err then
		vim.notify(err, vim.log.levels.ERROR)
	end
end, {})

vim.api.nvim_create_user_command("MatlabCurrentFile", function()
	local exec = require("config.matlab.exec")

	local path, err = exec.current_file()
	if not path then
		vim.notify(tostring(err), vim.log.levels.ERROR)
		return
	end

	vim.notify(path)
end, {})

vim.api.nvim_create_user_command("MatlabRunFile", function()
	local cmdwin = require("config.matlab.command_window")
	local exec = require("config.matlab.exec")

	if vim.bo.modified then
		vim.cmd.write()
	end

	local command, err = exec.command_from_current_file()
	if not command then
		vim.notify(tostring(err), vim.log.levels.ERROR)
		return
	end

	cmdwin.submit(command)
end, {})

vim.api.nvim_create_user_command("MatlabEval", function(opts)
	local exec = require("config.matlab.exec")

	local ok, err = exec.eval(opts.args)
	if not ok then
		vim.notify(tostring(err), vim.log.levels.ERROR)
		return
	end
end, {
	nargs = "+",
})

vim.api.nvim_create_user_command("MatlabOpenCommandWindow", function()
	local cmdwin = require("config.matlab.command_window")
	cmdwin.open()
end, {})
