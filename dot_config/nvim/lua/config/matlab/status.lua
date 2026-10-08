local M = {}

local progress_handle = nil

local function load_fidget()
	require("lazy").load({ plugins = { "fidget.nvim" } })
	return require("fidget.progress"), require("fidget")
end

local function clear_handle()
	progress_handle = nil
end

function M.update(state, opts)
	opts = opts or {}
	local progress, fidget = load_fidget()

	if state == "connecting" then
		if not progress_handle then
			progress_handle = progress.handle.create({
				title = "MATLAB",
				message = "Connecting to MATLAB...",
				lsp_client = { name = "matlab_ls_exec" },
			})
		end
		return
	end

	if state == "connected" then
		local release = " " .. assert(opts.release, "connected MATLAB status omitted its release")
		if progress_handle then
			progress_handle:report({
				message = "Connected to MATLAB" .. release,
			})
			progress_handle:finish()
			clear_handle()
		else
			fidget.notify("Connected to MATLAB" .. release, vim.log.levels.INFO, {
				group = "matlab",
				key = "matlab-connection",
				annote = "MATLAB",
			})
		end
		return
	end

	if state == "disconnected" then
		if progress_handle then
			progress_handle:cancel()
			clear_handle()
		end
		if opts.message then
			fidget.notify(opts.message, opts.level or vim.log.levels.WARN, {
				group = "matlab",
				key = "matlab-connection",
				annote = "MATLAB",
			})
		end
	end
end

function M.blocked(message)
	local _, fidget = load_fidget()
	fidget.notify(message, vim.log.levels.WARN, {
		group = "matlab",
		key = "matlab-exec-blocked",
		annote = "MATLAB",
	})
end

return M
