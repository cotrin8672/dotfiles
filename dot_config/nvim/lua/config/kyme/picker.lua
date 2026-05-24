local M = {}

local function command_text(command)
	return table.concat(command, " ")
end

local function task_source_text(task)
	if not task.source then
		return nil
	end

	local parts = { task.source.name }

	if task.source.path then
		table.insert(parts, task.source.path)
	end

	if task.source.line then
		table.insert(parts, tostring(task.source.line))
	end

	return table.concat(parts, ":")
end

local function task_preview_text(task)
	local lines = {
		("# %s"):format(task.name),
		"",
		"## Source",
		task_source_text(task) or "-",
		"",
		"## Command",
		"```sh",
		command_text(task.command),
		"```",
	}

	if task.desc and task.desc ~= "" then
		vim.list_extend(lines, {
			"",
			"## Description",
			task.desc,
		})
	end

	return table.concat(lines, "\n")
end

local function task_item(task)
	local source = task.source and task.source.name
	local text = source and ("%s: %s"):format(source, task.name) or task.name

	return {
		text = text,
		task = task,
		preview = {
			text = task_preview_text(task),
			ft = "markdown",
			loc = false,
		},
	}
end

local status_hl = {
	failed = "DiagnosticError",
	running = "DiagnosticInfo",
	stopped = "DiagnosticWarn",
	stopping = "DiagnosticWarn",
	succeeded = "DiagnosticOk",
}

local function execution_preview_lines(execution)
	local log = execution.log and execution.log.lines() or {}
	local first = math.max(#log - 80, 1)
	local tail = vim.list_slice(log, first, #log)
	local lines = {
		("# %s"):format(execution.task.name),
		"",
		"## Execution",
		("- ID: %s"):format(execution.id),
		("- Status: %s"):format(execution.status),
		("- Exit code: %s"):format(execution.exit_code ~= nil and tostring(execution.exit_code) or "-"),
		"",
		"## Command",
		"```sh",
		command_text(execution.task.command),
		"```",
		"",
		"## Log",
		"```text",
	}

	vim.list_extend(lines, tail)
	table.insert(lines, "```")

	return lines
end

local function execution_item(execution)
	return {
		text = ("#%s [%s] %s"):format(execution.id, execution.status, execution.task.name),
		execution = execution,
	}
end

local function execution_format(item)
	local execution = item.execution
	local ret = {
		{ ("#%s "):format(execution.id), "SnacksPickerIdx" },
		{ ("[%s] "):format(execution.status), status_hl[execution.status] or "Special" },
		{ execution.task.name },
	}

	return ret
end

local function clear_execution_preview_state(ctx)
	local state = ctx.preview.state.kyme_execution

	if not state then
		return
	end

	if state.unsubscribe then
		state.unsubscribe()
	end

	if state.timer then
		state.timer:stop()
		state.timer:close()
	end

	ctx.preview.state.kyme_execution = nil
end

local function render_execution_preview(ctx, execution)
	if not vim.api.nvim_buf_is_valid(ctx.buf) then
		return
	end

	ctx.preview:set_lines(execution_preview_lines(execution))
	vim.bo[ctx.buf].filetype = "markdown"
	ctx.preview:highlight({ ft = "markdown" })
end

local function execution_preview(ctx)
	local execution = ctx.item.execution

	clear_execution_preview_state(ctx)

	ctx.preview:reset()
	ctx.preview:set_title(("#%s %s"):format(execution.id, execution.task.name))
	render_execution_preview(ctx, execution)

	local state = {}
	ctx.preview.state.kyme_execution = state

	if execution.log and execution.log.subscribe then
		state.unsubscribe = execution.log.subscribe(function()
			vim.schedule(function()
				if ctx.preview.state.kyme_execution == state then
					render_execution_preview(ctx, execution)
				end
			end)
		end)
	end

	state.timer = vim.uv.new_timer()
	state.timer:start(500, 500, function()
		vim.schedule(function()
			if ctx.preview.state.kyme_execution ~= state then
				return
			end

			render_execution_preview(ctx, execution)

			if execution.status ~= "running" and execution.status ~= "stopping" then
				clear_execution_preview_state(ctx)
			end
		end)
	end)

	if not ctx.preview.state.kyme_execution_close_registered then
		ctx.preview.state.kyme_execution_close_registered = true
		ctx.preview.win:on("WinClosed", function()
			clear_execution_preview_state(ctx)
		end, { win = true })
	end
end

function M.tasks()
	local kyme = require("kyme")

	kyme.collect(function(tasks)
		Snacks.picker({
			source = "kyme_tasks",
			title = "Kyme Tasks",
			items = vim.tbl_map(task_item, tasks),
			format = "text",
			preview = "preview",
			confirm = function(picker, item)
				picker:close()

				if item and item.task then
					kyme.run(item.task)
				end
			end,
		})
	end)
end

function M.executions()
	local executions = require("kyme.executions")

	Snacks.picker({
		source = "kyme_executions",
		title = "Kyme Executions",
		items = vim.tbl_map(execution_item, executions.list()),
		format = execution_format,
		preview = execution_preview,
		confirm = function(picker)
			picker:close()
		end,
		actions = {
			stop_execution = function(_, item)
				if item and item.execution then
					executions.stop(item.execution.id)
				end
			end,
		},
		win = {
			input = {
				keys = {
					["<M-s>"] = { "stop_execution", mode = { "n", "i" } },
				},
			},
			list = {
				keys = {
					["<M-s>"] = "stop_execution",
				},
			},
		},
	})
end

return M
