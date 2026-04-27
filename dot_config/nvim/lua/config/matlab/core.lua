local M = {}

local requested_clients = {}

function M.setup(user_opts)
	local opts = vim.tbl_deep_extend("force", {
		auto_start = false,
		auto_start_delay = 500,
	}, user_opts or {})

	if not opts.auto_start then
		return
	end

	local group = vim.api.nvim_create_augroup("MatlabLspAutoStart", {
		clear = true,
	})

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)

			if not client or client.name ~= "matlab_ls" then
				return
			end

			if requested_clients[client.id] then
				return
			end
			requested_clients[client.id] = true

			vim.defer_fn(function()
				local ok, err = M.notify("matlab/request", {})
				if not ok then
					vim.notify(tostring(err), vim.log.levels.ERROR)
				end
			end, opts.auto_start_delay)
		end,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(args)
			requested_clients[args.data.client_id] = nil
		end,
	})
end

function M.get_client()
	local clients = vim.lsp.get_clients()
	for _, client in ipairs(clients) do
		if client.name == "matlab_ls" then
			return client
		end
	end

	return nil, "matlab_ls client not found"
end

function M.notify(method, params)
	local client, err = M.get_client()
	if not client then
		return false, err
	end

	client:notify(method, params or {})
	return true, nil
end

function M.request(method, params, handler, bufnr)
	local client, err = M.get_client()
	if not client then
		return nil, err
	end

	local request_id = client:request(method, params or {}, handler, bufnr)

	return request_id, nil
end

function M.new_request_id()
	return tostring(vim.uv.hrtime())
end

function M.interrupt()
	return M.notify("interruptRequest", {})
end

return M
