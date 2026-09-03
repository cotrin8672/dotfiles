local M = {}

local WSB_CLIENT_MESSAGE = "WSBClientMessage"
local MINIMUM_RELEASE = "R2023a"
local STARTUP_COMMAND = "internal.matlab.desktop_workspacebrowser.MobileWorkspaceBrowser.startup;"

local DEFAULT_COLUMNS = { "Name", "Value", "Size", "Class" }

local opts = {
	width_ratio = 0.8,
	height_ratio = 0.7,
	max_width = 120,
	max_height = 30,
	debounce_ms = 100,
	startup_timeout_ms = 5000,
}

local state = {
	bufnr = nil,
	winid = nil,
	picker = nil,
	source_bufnr = nil,
	connected = false,
	release = nil,
	supported = false,
	startup_requested = false,
	server_responded = false,
	startup_token = 0,
	columns = vim.deepcopy(DEFAULT_COLUMNS),
	rows = nil,
	row_count = 0,
	column_count = 0,
	dirty = true,
	loading = false,
	error = nil,
	debounce_token = 0,
	pending_request = nil,
	initialized = false,
}

local function core()
	return require("config.matlab.core")
end

local function ensure_exec_client()
	local bufnr = state.source_bufnr
	if bufnr and not vim.api.nvim_buf_is_valid(bufnr) then
		bufnr = nil
	end
	return core().ensure_client(bufnr)
end

local function is_float_visible()
	return state.winid ~= nil and vim.api.nvim_win_is_valid(state.winid)
end

local function is_picker_visible()
	return state.picker ~= nil and not state.picker.closed
end

local function is_workspace_visible()
	return is_float_visible() or is_picker_visible()
end

local function sanitize(value)
	return tostring(value or ""):gsub("[\r\n\t]", " ")
end

local function truncate(value, width)
	value = sanitize(value)
	if width <= 0 then
		return ""
	end
	if vim.fn.strdisplaywidth(value) <= width then
		return value
	end
	if width == 1 then
		return "…"
	end

	local kept = ""
	local char_count = vim.fn.strchars(value)
	for index = 0, char_count - 1 do
		local candidate = kept .. vim.fn.strcharpart(value, index, 1)
		if vim.fn.strdisplaywidth(candidate) > width - 1 then
			break
		end
		kept = candidate
	end
	return kept .. "…"
end

local function pad(value, width)
	value = truncate(value, width)
	return value .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(value)))
end

local function dimensions()
	local available_width = math.max(1, vim.o.columns - 2)
	local available_height = math.max(1, vim.o.lines - 3)
	local width = math.min(opts.max_width, math.max(1, math.floor(vim.o.columns * opts.width_ratio)))
	local height = math.min(opts.max_height, math.max(1, math.floor(vim.o.lines * opts.height_ratio)))
	width = math.min(width, available_width)
	height = math.min(height, available_height)

	return {
		width = width,
		height = height,
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		row = math.max(0, math.floor((vim.o.lines - height - 1) / 2)),
	}
end

local function table_widths(width)
	local usable = math.max(4, width - 6)
	local name = math.max(1, math.floor(usable * 0.22))
	local size = math.max(1, math.floor(usable * 0.16))
	local class = math.max(1, math.floor(usable * 0.18))
	local value = math.max(1, usable - name - size - class)
	return { name, value, size, class }
end

local function format_row(values, widths)
	local fields = {}
	for index = 1, #widths do
		fields[index] = pad(values[index] or "", widths[index])
	end
	return table.concat(fields, "  ")
end

local function ensure_buffer()
	if state.bufnr and vim.api.nvim_buf_is_valid(state.bufnr) then
		return state.bufnr
	end

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, "[MATLAB Workspace]")
	vim.bo[bufnr].buftype = "nofile"
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].filetype = "matlab-workspace"

	vim.keymap.set("n", "q", function()
		if is_float_visible() then
			vim.api.nvim_win_close(state.winid, false)
			state.winid = nil
		end
	end, { buffer = bufnr, silent = true, nowait = true, desc = "Close MATLAB workspace" })

	vim.keymap.set("n", "<Esc>", function()
		if is_float_visible() then
			vim.api.nvim_win_close(state.winid, false)
			state.winid = nil
		end
	end, { buffer = bufnr, silent = true, nowait = true, desc = "Close MATLAB workspace" })

	vim.keymap.set("n", "r", function()
		M.refresh()
	end, { buffer = bufnr, silent = true, nowait = true, desc = "Refresh MATLAB workspace" })

	state.bufnr = bufnr
	return bufnr
end

local function render()
	local bufnr = ensure_buffer()
	local lines = {}
	local views = {}
	for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
		if vim.api.nvim_win_is_valid(winid) then
			views[winid] = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
		end
	end

	if state.error then
		lines = { "MATLAB Workspace", "", "Error: " .. state.error }
	elseif not state.connected then
		local connection = core().connection_state()
		if connection == "connecting" then
			lines = { "MATLAB Workspace", "", "Connecting to MATLAB..." }
		else
			lines = { "MATLAB Workspace", "", "MATLAB is not connected." }
		end
	elseif not state.supported then
		lines = { "MATLAB Workspace", "", "Workspace Browser is unavailable." }
	else
		local width = is_float_visible() and vim.api.nvim_win_get_width(state.winid) or dimensions().width
		local widths = table_widths(width)
		local header = format_row(DEFAULT_COLUMNS, widths)
		lines = { header, string.rep("─", math.max(1, vim.fn.strdisplaywidth(header))) }

		if state.rows == nil then
			table.insert(
				lines,
				state.loading and "Loading workspace variables..." or "Workspace data has not been loaded."
			)
		elseif #state.rows == 0 then
			table.insert(lines, "(no workspace variables)")
		else
			for _, row in ipairs(state.rows) do
				table.insert(
					lines,
					format_row({
						row.Name,
						row.Value,
						row.Size,
						row.Class,
					}, widths)
				)
			end
		end

		if state.loading and state.rows ~= nil then
			table.insert(lines, "")
			table.insert(lines, "Refreshing...")
		end
	end

	vim.bo[bufnr].modifiable = true
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	for winid, view in pairs(views) do
		if vim.api.nvim_win_is_valid(winid) then
			vim.api.nvim_win_call(winid, function()
				vim.fn.winrestview(view)
			end)
		end
	end
end

local numeric_classes = {
	double = true,
	single = true,
	int8 = true,
	int16 = true,
	int32 = true,
	int64 = true,
	uint8 = true,
	uint16 = true,
	uint32 = true,
	uint64 = true,
}

local function variable_icon(row)
	local class = row.Class:lower()
	if class == "cell" then
		return "{}", "Special"
	elseif class == "struct" then
		return "", "Type"
	elseif class == "logical" then
		return "◉", "Boolean"
	elseif class == "char" or class == "string" then
		return "“", "String"
	elseif class == "function_handle" then
		return "ƒ", "Function"
	elseif class == "table" or class == "timetable" then
		return "▤", "Type"
	elseif numeric_classes[class] then
		local size = row.Size:gsub("%s", "")
		return (size == "1x1" or size == "1×1") and "#" or "▦", "Number"
	end
	return "●", "Type"
end

local function icon_field(icon)
	return icon .. string.rep(" ", math.max(0, 2 - vim.fn.strdisplaywidth(icon))) .. " "
end

local function picker_items()
	if state.error then
		return { { text = state.error, message = "Error: " .. state.error } }
	elseif not state.connected then
		local message = state.loading and "Connecting to MATLAB..." or "MATLAB is not connected."
		return { { text = message, message = message } }
	elseif not state.supported then
		return { { text = "Workspace Browser is unavailable.", message = "Workspace Browser is unavailable." } }
	elseif state.rows == nil then
		local message = state.loading and "Loading workspace variables..." or "Workspace data has not been loaded."
		return { { text = message, message = message } }
	elseif #state.rows == 0 then
		return { { text = "(no workspace variables)", message = "(no workspace variables)" } }
	end

	return vim.tbl_map(function(row)
		local icon, icon_hl = variable_icon(row)
		return {
			text = table.concat({ row.Name, row.Class, row.Size, row.Value }, " "),
			row = row,
			icon = icon,
			icon_hl = icon_hl,
		}
	end, state.rows)
end

local function picker_format(item)
	if not item.row then
		return { { item.message, "Comment" } }
	end
	return {
		{ icon_field(item.icon), item.icon_hl },
		{ item.row.Name, "Identifier" },
		{ "  " .. item.row.Value, "Comment" },
		{ "  " .. item.row.Size, "Comment" },
		{ "  " .. item.row.Class, "Type" },
	}
end

local function picker_preview(ctx)
	ctx.preview:reset()
	if not ctx.item.row then
		ctx.preview:set_title("MATLAB Workspace")
		ctx.preview:set_lines({ ctx.item.message })
		return
	end

	local row = ctx.item.row
	ctx.preview:set_title(row.Name)
	ctx.preview:set_lines({
		("# %s"):format(row.Name),
		"",
		("- Class: `%s`"):format(row.Class),
		("- Size: `%s`"):format(row.Size),
		"",
		"## Value",
		"```matlab",
		row.Value,
		"```",
	})
	vim.bo[ctx.buf].filetype = "markdown"
	ctx.preview:highlight({ ft = "markdown" })
end

local function refresh_picker()
	if is_picker_visible() then
		state.picker:refresh()
	elseif state.picker then
		state.picker = nil
	end
end

local function refresh_views()
	if is_float_visible() then
		render()
	end
	refresh_picker()
end

local function open_picker()
	local picker
	picker = Snacks.picker({
		source = "matlab_workspace",
		title = "MATLAB Workspace",
		finder = picker_items,
		format = picker_format,
		preview = picker_preview,
		confirm = function(current)
			current:close()
		end,
		on_close = function(closed)
			if state.picker == closed then
				state.picker = nil
			end
		end,
		actions = {
			refresh_workspace = function()
				M.refresh()
			end,
		},
		win = {
			input = { keys = { ["<C-r>"] = { "refresh_workspace", mode = { "n", "i" } } } },
			list = { keys = { ["r"] = "refresh_workspace" } },
		},
	})
	state.picker = picker
	return picker
end

local function open_window()
	local bufnr = ensure_buffer()
	local size = dimensions()
	local float_opts = {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		title = " MATLAB Workspace ",
		title_pos = "center",
		width = size.width,
		height = size.height,
		col = size.col,
		row = size.row,
	}

	state.winid = vim.api.nvim_open_win(bufnr, true, float_opts)
	vim.wo[state.winid].wrap = false
	vim.wo[state.winid].number = false
	vim.wo[state.winid].relativenumber = false
	vim.wo[state.winid].signcolumn = "no"
	vim.wo[state.winid].foldcolumn = "0"
	vim.wo[state.winid].cursorline = true

	vim.wo[state.winid].winblend = require("shared.float").blend

	render()
	return state.winid
end

local function update_window_dimensions()
	if not is_float_visible() then
		return
	end
	local size = dimensions()
	vim.api.nvim_win_set_config(state.winid, {
		relative = "editor",
		width = size.width,
		height = size.height,
		col = size.col,
		row = size.row,
	})
	render()
end

local function parse_release(release)
	local year, half = tostring(release or ""):lower():match("^r?(%d+)([ab])$")
	if not year then
		return nil
	end
	if #year == 2 then
		year = "20" .. year
	elseif #year ~= 4 then
		return nil
	end
	return tonumber(year) * 2 + (half == "b" and 1 or 0)
end

local function release_supported(release)
	local current = parse_release(release)
	local minimum = assert(parse_release(MINIMUM_RELEASE))
	return current ~= nil and current >= minimum
end

local function validate_support(release)
	if not release_supported(release) then
		return false,
			("Workspace Browser requires MATLAB %s or later (connected: %s)"):format(
				MINIMUM_RELEASE,
				tostring(release or "unknown")
			)
	end

	return true
end

local function protocol_error(message)
	state.loading = false
	state.dirty = true
	state.error = "Workspace Browser protocol error: " .. message
	refresh_views()
	return false
end

local function notify_wsb(params)
	local ok, err = core().notify_exec(WSB_CLIENT_MESSAGE, params)
	if ok == false then
		state.loading = false
		state.error = tostring(err)
		refresh_views()
		return false
	end
	return true
end

local function request_size()
	state.loading = true
	state.error = nil
	local ok = notify_wsb({ type = "GetSize" })
	refresh_views()
	return ok
end

local function request_columns()
	return notify_wsb({ type = "GetVisibleColumns" })
end

local function request_data()
	if state.row_count == 0 then
		state.rows = {}
		state.loading = false
		state.dirty = false
		refresh_views()
		return true
	end

	state.loading = true
	local ok = notify_wsb({
		type = "GetData",
		startRow = 1,
		endRow = state.row_count + 1,
	})
	refresh_views()
	return ok
end

local function cancel_debounce()
	state.debounce_token = state.debounce_token + 1
	state.pending_request = nil
end

local function schedule_request(kind)
	if not is_workspace_visible() then
		state.dirty = true
		return
	end
	if not state.connected or not state.supported then
		return
	end

	state.pending_request = kind
	state.debounce_token = state.debounce_token + 1
	local token = state.debounce_token

	vim.defer_fn(function()
		if token ~= state.debounce_token then
			return
		end
		local pending = state.pending_request
		state.pending_request = nil
		if not is_workspace_visible() or not state.connected or not state.supported then
			state.dirty = true
			return
		end
		if pending == "size" then
			request_size()
		else
			request_data()
		end
	end, opts.debounce_ms)
end

local function start_backend()
	if state.startup_requested then
		return true
	end

	state.startup_requested = true
	state.server_responded = false
	state.startup_token = state.startup_token + 1
	local ok, err = core().enqueue_eval(STARTUP_COMMAND, {
		is_user_eval = false,
		on_complete = function(success, result_or_error)
			if not success then
				assert(result_or_error ~= nil, "failed workspace startup evaluation omitted its error")
				state.startup_requested = false
				state.loading = false
				state.error = "Failed to start Workspace Browser: " .. tostring(result_or_error)
				refresh_views()
				return
			end
			if not state.startup_requested or not state.connected then
				return
			end

			if not state.server_responded then
				state.startup_token = state.startup_token + 1
				local startup_token = state.startup_token
				vim.defer_fn(function()
					if startup_token ~= state.startup_token or state.server_responded or not state.connected then
						return
					end
					state.startup_requested = false
					state.loading = false
					state.dirty = true
					state.error = "Workspace Browser did not respond; press r to retry startup"
					refresh_views()
				end, opts.startup_timeout_ms)
			end

			if not request_size() then
				state.startup_requested = false
				state.startup_token = state.startup_token + 1
			end
		end,
	})
	if ok == false then
		assert(err ~= nil, "workspace startup enqueue failed without an error")
		state.startup_requested = false
		state.error = "Failed to start Workspace Browser: " .. tostring(err)
		refresh_views()
		return false
	end
	if not state.startup_requested or not state.connected then
		return false, state.error
	end
	return true
end

local function update_size(raw_row_count, raw_column_count)
	if type(raw_row_count) ~= "number" or raw_row_count < 0 or raw_row_count % 1 ~= 0 then
		return protocol_error("Size.rowCount must be a non-negative integer")
	end
	if type(raw_column_count) ~= "number" or raw_column_count < 0 or raw_column_count % 1 ~= 0 then
		return protocol_error("Size.columnCount must be a non-negative integer")
	end

	local columns_changed = raw_column_count ~= state.column_count
	state.row_count = raw_row_count
	state.column_count = raw_column_count
	if columns_changed then
		return request_columns()
	end
	return true
end

local function handle_columns(result)
	if type(result.columns) ~= "table" then
		return protocol_error("Columns.columns must be a table")
	end
	local columns = {}
	for _, column in ipairs(result.columns) do
		if type(column) ~= "table" or type(column.column) ~= "string" or column.column == "" then
			return protocol_error("each Columns entry must contain a non-empty column string")
		end
		table.insert(columns, column.column)
	end
	if #columns == 0 then
		return protocol_error("Columns.columns must not be empty")
	end
	for _, required in ipairs(DEFAULT_COLUMNS) do
		if not vim.list_contains(columns, required) then
			return protocol_error("Columns.columns omitted " .. required)
		end
	end
	state.columns = columns
	return true
end

local function handle_data(result)
	if type(result.data) ~= "table" then
		return protocol_error("Data.data must be a table")
	end

	local rows = {}
	for _, raw_row in ipairs(result.data) do
		if type(raw_row) ~= "table" or type(raw_row.data) ~= "table" then
			return protocol_error("each Data row must contain a data table")
		end
		local fields = {}
		for index, column in ipairs(state.columns) do
			if raw_row.data[index] == nil then
				return protocol_error("Data row omitted the " .. column .. " value")
			end
			fields[column] = sanitize(raw_row.data[index])
		end
		table.insert(rows, {
			Name = fields.Name,
			Value = fields.Value,
			Size = fields.Size,
			Class = fields.Class,
		})
	end

	state.rows = rows
	state.row_count = math.max(state.row_count, #rows)
	state.loading = false
	state.dirty = false
	state.error = nil
	refresh_views()
end

function M.setup(user_opts)
	opts = vim.tbl_deep_extend("force", opts, user_opts or {})
	state.initialized = true

	local group = vim.api.nvim_create_augroup("MatlabWorkspaceFloat", { clear = true })
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = update_window_dimensions,
	})
end

function M.toggle()
	if not state.initialized then
		M.setup()
	end

	if is_picker_visible() then
		state.picker:close()
		return
	end

	local current_bufnr = vim.api.nvim_get_current_buf()
	if current_bufnr ~= state.bufnr then
		state.source_bufnr = current_bufnr
	end
	open_picker()
	local connection, release = core().connection_state()
	if connection == "connected" then
		if not state.connected or state.release ~= release then
			M.on_connected(release)
		elseif state.dirty or state.rows == nil then
			M.refresh()
		end
		return
	end

	state.connected = false
	state.release = release
	state.loading = connection == "connecting"
	state.error = nil
	refresh_views()
	local ok, err = ensure_exec_client()
	if ok == false then
		assert(err ~= nil, "matlab_ls_exec startup failed without an error")
		state.loading = false
		state.error = tostring(err)
		refresh_views()
	end
end

function M.refresh()
	local connection, release = core().connection_state()
	if connection ~= "connected" then
		state.connected = false
		state.release = release
		state.dirty = true
		state.loading = connection == "connecting"
		state.error = nil
		local ok, err = ensure_exec_client()
		if ok == false then
			assert(err ~= nil, "matlab_ls_exec startup failed without an error")
			state.loading = false
			state.error = tostring(err)
		end
		refresh_views()
		return ok, err
	end

	if not state.connected or state.release ~= release then
		M.on_connected(release)
		return state.supported, state.error
	end
	if not state.supported then
		return false, state.error
	end
	if not state.startup_requested then
		return start_backend()
	end

	state.dirty = true
	request_columns()
	return request_size()
end

function M.on_connected(release)
	state.connected = true
	state.release = release
	state.error = nil
	state.loading = true
	state.dirty = true

	local supported, err = validate_support(release)
	state.supported = supported
	if not supported then
		state.loading = false
		state.error = err
		refresh_views()
		return false, err
	end

	refresh_views()
	return start_backend()
end

function M.on_disconnected(message)
	cancel_debounce()
	state.connected = false
	state.release = nil
	state.supported = false
	state.startup_requested = false
	state.server_responded = false
	state.startup_token = state.startup_token + 1
	state.columns = vim.deepcopy(DEFAULT_COLUMNS)
	state.rows = nil
	state.row_count = 0
	state.column_count = 0
	state.dirty = true
	state.loading = false
	state.error = message and tostring(message) or nil
	refresh_views()
end

function M.on_eval_complete()
	if not state.connected or not state.supported then
		return
	end
	schedule_request("size")
end

function M.handle_server_message(result, client_id)
	local client = core().get_exec_client()
	if not client or client.id ~= client_id then
		return
	end
	if not state.connected or not state.supported then
		return
	end
	if type(result) ~= "table" or type(result.type) ~= "string" then
		protocol_error("message must contain a string type")
		return
	end
	state.server_responded = true
	state.startup_token = state.startup_token + 1

	if result.type == "Size" then
		if not update_size(result.rowCount, result.columnCount) then
			return
		end
		if is_workspace_visible() then
			schedule_request("data")
		else
			state.dirty = true
		end
	elseif result.type == "Columns" then
		if not handle_columns(result) then
			return
		end
		if state.rows ~= nil then
			refresh_views()
		end
	elseif result.type == "Data" then
		handle_data(result)
	elseif result.type == "DataChanged" then
		if not update_size(result.rowCount, result.columnCount) then
			return
		end
		schedule_request("data")
	elseif result.type == "WorkspaceBrowserStarted" then
		if request_size() then
			request_columns()
		end
	elseif result.type == "InternalError" then
		if type(result.message) ~= "string" or result.message == "" then
			protocol_error("InternalError.message must be a non-empty string")
			return
		end
		state.startup_requested = false
		state.loading = false
		state.dirty = true
		state.error = "Workspace Browser server error: " .. result.message .. "; press r to retry startup"
		refresh_views()
	else
		protocol_error("unknown message type: " .. result.type)
	end
end

return M
