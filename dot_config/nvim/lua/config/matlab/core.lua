local M = {}

local requested_clients = {}
local connection = {
	state = "disconnected",
	release = nil,
}

local function status()
	return require("config.matlab.status")
end

local function set_connection_state(state, opts)
	opts = opts or {}
	connection.state = state
	connection.release = opts.release
	status().update(state, opts)
end

function M.setup(user_opts)
	local opts = vim.tbl_deep_extend("force", {
		auto_start = false,
		auto_start_delay = 500,
	}, user_opts or {})

	if not opts.auto_start then
		return
	end

	local function request_start(client)
		if not client or client.name ~= "matlab_ls" then
			return
		end

		if requested_clients[client.id] then
			return
		end
		requested_clients[client.id] = true

		vim.defer_fn(function()
			set_connection_state("connecting")
			local ok, err = M.notify("matlab/request", {})
			if not ok then
				set_connection_state("disconnected")
				vim.notify(tostring(err), vim.log.levels.ERROR)
			end
		end, opts.auto_start_delay)
	end

	local group = vim.api.nvim_create_augroup("MatlabLspAutoStart", {
		clear = true,
	})

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			request_start(client)
		end,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client and client.name ~= "matlab_ls" then
				return
			end
			if not client and not requested_clients[args.data.client_id] then
				return
			end

			requested_clients[args.data.client_id] = nil
			set_connection_state("disconnected")
		end,
	})

	for _, client in ipairs(vim.lsp.get_clients({ name = "matlab_ls" })) do
		request_start(client)
	end
end

function M.handle_mvm_state_change(result)
	if not result or not result.state then
		return
	end

	if result.state == "connected" then
		set_connection_state("connected", {
			release = result.release,
		})
	elseif result.state == "disconnected" then
		set_connection_state("disconnected")
	end
end

function M.handle_launch_failed()
	set_connection_state("disconnected", {
		message = "Failed to connect to MATLAB",
		level = vim.log.levels.ERROR,
	})
end

function M.is_connected()
	return connection.state == "connected"
end

function M.connection_state()
	return connection.state, connection.release
end

function M.connection_error()
	if connection.state == "connecting" then
		return "MATLAB is still connecting"
	end

	return "MATLAB is not connected"
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
