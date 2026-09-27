describe("MATLAB workspace picker", function()
	local workspace
	local fake_core
	local notifications
	local evals
	local picker, previous_snacks
	local function buffer_text()
		return table.concat(vim.tbl_map(function(item)
			return item.message or item.text
		end, picker.items), "\n")
	end

	before_each(function()
		previous_snacks = _G.Snacks
		_G.Snacks = { picker = function(opts)
			picker = {
				closed = false,
				refreshes = 0,
				items = opts.finder(),
				refresh = function(self)
					self.refreshes = self.refreshes + 1
					self.items = opts.finder()
				end,
				close = function(self)
					self.closed = true
					opts.on_close(self)
				end,
			}
			return picker
		end }
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
		picker:close()
		_G.Snacks = previous_snacks
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

	it("keeps identical data stable and refreshes changed values and error recovery", function()
		workspace.toggle()
		evals[1].opts.on_complete(true, {})
		local data = { type = "Data", data = { { data = { "x", "1", "1x1", "double" } } } }
		workspace.handle_server_message(data, 42)
		local before, items = picker.refreshes, picker.items
		workspace.handle_server_message(vim.deepcopy(data), 42)
		assert.are.equal(before, picker.refreshes)
		assert.are.equal(items, picker.items)
		data.data[1].data[2] = "2"
		workspace.handle_server_message(data, 42)
		assert.are.equal(before + 1, picker.refreshes)
		assert.are.equal("2", picker.items[1].row.Value)
		workspace.handle_server_message({ type = "Data", data = { {} } }, 42)
		assert.matches("protocol error", buffer_text())
		workspace.handle_server_message(data, 42)
		assert.are.equal("2", picker.items[1].row.Value)
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
