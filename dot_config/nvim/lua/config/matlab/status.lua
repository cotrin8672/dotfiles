local M = {}

local progress_handle = nil

local function load_fidget()
	local lazy_ok, lazy = pcall(require, "lazy")
	if lazy_ok then
		pcall(lazy.load, { plugins = { "fidget.nvim" } })
	end

	local progress_ok, progress = pcall(require, "fidget.progress")
	local fidget_ok, fidget = pcall(require, "fidget")
	return progress_ok and progress or nil, fidget_ok and fidget or nil
end

local function notify(message, level, opts)
	local _, fidget = load_fidget()
	if fidget then
		fidget.notify(message, level, opts)
		return
	end

	vim.notify(message, level)
end

local function clear_handle()
	progress_handle = nil
end

function M.update(state, opts)
	opts = opts or {}
	local progress = load_fidget()

	if state == "connecting" then
		if progress and not progress_handle then
			progress_handle = progress.handle.create({
				title = "MATLAB",
				message = "Connecting to MATLAB...",
				lsp_client = { name = "matlab_ls" },
			})
		elseif not progress then
			vim.notify("Connecting to MATLAB...", vim.log.levels.INFO)
		end
		return
	end

	if state == "connected" then
		local release = opts.release and (" " .. opts.release) or ""
		if progress_handle then
			progress_handle:report({
				message = "Connected to MATLAB" .. release,
			})
			progress_handle:finish()
			clear_handle()
		else
			notify("Connected to MATLAB" .. release, vim.log.levels.INFO, {
				group = "matlab",
				key = "matlab-connection",
				annote = "MATLAB",
			})
		end
		return
	end

	if state == "disconnected" then
		if progress_handle then
			pcall(progress_handle.cancel, progress_handle)
			clear_handle()
		end
		if opts.message then
			notify(opts.message, opts.level or vim.log.levels.WARN, {
				group = "matlab",
				key = "matlab-connection",
				annote = "MATLAB",
			})
		end
	end
end

function M.blocked(message)
	notify(message, vim.log.levels.WARN, {
		group = "matlab",
		key = "matlab-exec-blocked",
		annote = "MATLAB",
	})
end

return M
