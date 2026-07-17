local function workspace_buffer()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr):match("%[MATLAB Workspace%]$") then
			return bufnr
		end
	end
end

local function buffer_text()
	local bufnr = assert(workspace_buffer())
	return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

describe("MATLAB workspace float", function()
	local workspace
	local fake_core
	local notifications
	local evals

	before_each(function()
		notifications = {}
		evals = {}
		fake_core = {
			state = "connected",
			release = "R2024a",
			client = { id = 42, name = "matlab_ls_exec" },
			connection_state = function()
				return fake_core.state, fake_core.release
			end,
			ensure_client = function()
				return true, nil
			end,
			get_exec_client = function()
				return fake_core.client, nil
			end,
			enqueue_eval = function(command, opts)
				table.insert(evals, { command = command, opts = opts })
				return true, nil
			end,
			notify_exec = function(method, params)
				table.insert(notifications, { method = method, params = params })
				return true, nil
			end,
		}
		package.loaded["config.matlab.core"] = fake_core
		package.loaded["config.matlab.workspace"] = nil
		workspace = require("config.matlab.workspace")
		workspace.setup({ debounce_ms = 0, startup_timeout_ms = 100 })
	end)

	after_each(function()
		local bufnr = workspace_buffer()
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
				if vim.api.nvim_win_is_valid(winid) then
					vim.api.nvim_win_close(winid, true)
				end
			end
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
		package.loaded["config.matlab.core"] = nil
		package.loaded["config.matlab.workspace"] = nil
	end)

	it("starts the native backend and renders positional workspace data", function()
		workspace.toggle()
		assert.are.equal(1, #evals)
		assert.matches("MobileWorkspaceBrowser.startup", evals[1].command)
		assert.is_false(evals[1].opts.is_user_eval)
		assert.are.equal(0, #notifications)

		evals[1].opts.on_complete(true, {})
		assert.same({ type = "GetSize" }, notifications[1].params)

		workspace.handle_server_message({
			type = "Columns",
			columns = {
				{ column = "Name" },
				{ column = "Value" },
				{ column = "Size" },
				{ column = "Class" },
			},
		}, 42)
		workspace.handle_server_message({ type = "Size", rowCount = 2, columnCount = 4 }, 42)
		vim.wait(20)
		local get_data = notifications[#notifications].params
		assert.same({ type = "GetData", startRow = 1, endRow = 3 }, get_data)

		workspace.handle_server_message({
			type = "Data",
			data = {
				{ rowNum = 1, data = { "x", "42", "1x1", "double" } },
				{ rowNum = 2, data = { "items", "{1x2 cell}", "1x2", "cell" } },
			},
		}, 42)
		local text = buffer_text()
		assert.matches("x", text)
		assert.matches("42", text)
		assert.matches("double", text)
		assert.matches("items", text)
	end)

	it("marks hidden data changes dirty and refreshes when reopened", function()
		workspace.toggle()
		evals[1].opts.on_complete(true, {})
		workspace.handle_server_message({ type = "Size", rowCount = 1, columnCount = 4 }, 42)
		workspace.toggle()
		local before = #notifications

		workspace.handle_server_message({ type = "DataChanged", rowCount = 2, columnCount = 4 }, 42)
		vim.wait(20)
		assert.are.equal(before, #notifications)

		workspace.toggle()
		assert.is_true(#notifications > before)
		assert.same({ type = "GetSize" }, notifications[#notifications].params)
	end)

	it("rejects MATLAB releases older than R2023a without starting the backend", function()
		fake_core.release = "R2022b"
		workspace.toggle()

		assert.are.equal(0, #evals)
		assert.matches("R2023a", buffer_text())
	end)

	it("ignores workspace messages from a stale client", function()
		workspace.toggle()
		evals[1].opts.on_complete(true, {})
		local before = #notifications
		workspace.handle_server_message({ type = "WorkspaceBrowserStarted" }, 7)
		assert.are.equal(before, #notifications)
	end)

	it("shows malformed server data as a protocol error instead of an empty workspace", function()
		workspace.toggle()
		evals[1].opts.on_complete(true, {})

		workspace.handle_server_message({ type = "Size", rowCount = "2", columnCount = 4 }, 42)

		assert.matches("protocol error", buffer_text())
		assert.matches("rowCount", buffer_text())
	end)

	it("offers a real startup retry after the workspace backend times out", function()
		workspace.toggle()
		evals[1].opts.on_complete(true, {})
		vim.wait(150)

		assert.matches("press r to retry startup", buffer_text())
		workspace.refresh()
		assert.are.equal(2, #evals)
	end)
end)
