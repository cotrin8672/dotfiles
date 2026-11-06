-- nvim --headless -u NONE -i NONE -n -c "lua dofile('tests/nvim_julia_completion.lua')"
local config = vim.fn.fnamemodify("dot_config/nvim", ":p"):gsub("[/\\]$", "")
vim.opt.rtp:prepend(config)
for _, plugin in ipairs({ "nvim-autopairs", "LuaSnip", "blink.lib", "blink.cmp" }) do
	vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/" .. plugin)
end
local opts = vim.deepcopy(require("plugins.blink").opts)
opts.sources.default = { "path" }
opts.sources.providers = { path = opts.sources.providers.path }
opts.fuzzy = { implementation = "lua", frecency = { enabled = false }, use_proximity = false }
local blink = require("blink.cmp")
blink.setup(opts)
local pairs = require("plugins.nvim-autopairs")
pairs.config(nil, pairs.opts)

local directory = vim.fn.tempname()
vim.fn.mkdir(directory .. "/sub", "p")
local files = {}
for _, folder in ipairs({ "", "sub/" }) do
	for _, name in ipairs({ "simd.jl", "main.jl", "LLEStep.jl" }) do
		local path = directory .. "/" .. folder .. name
		vim.fn.writefile({ "# completion fixture" }, path)
		table.insert(files, path)
	end
end
local function cleanup()
	for _, path in ipairs(files) do
		vim.fn.delete(path)
	end
	vim.fn.delete(directory .. "/sub", "d")
	vim.fn.delete(directory, "d")
end

local steps = {}
for case, prefix in ipairs({ "", "si", "./", "sub/" }) do
	local initial = 'include("' .. prefix
	local basename_start = #initial - #(prefix:match("[^/]*$") or "")
	table.insert(steps, function()
		blink.hide()
		local buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_set_current_buf(buf)
		vim.api.nvim_buf_set_name(buf, directory .. "/scratch" .. case .. ".jl")
		vim.bo.filetype = "julia"
		vim.api.nvim_input("i" .. initial)
	end)
	table.insert(steps, function()
		assert(blink.is_visible(), "Missing include path menu: " .. prefix .. " " .. vim.inspect({
			line = vim.api.nvim_get_current_line(),
			pos = vim.api.nvim_win_get_cursor(0),
			items = blink.get_items(),
		}))
		local items = blink.get_items()
		if prefix == "" then
			assert(#items >= 3, "Need multiple files to catch shared edit ranges")
		end
		for _, item in ipairs(items) do
			local range = item.textEdit.range
			assert(range.start.character == basename_start, "Wrong insertion start: " .. vim.inspect(range))
			assert(range["end"].character == #initial, "Wrong insertion end: " .. vim.inspect(range))
		end
		for _ = 1, #items do
			if blink.get_selected_item().label == "simd.jl" then
				return
			end
			blink.select_next()
		end
		error("simd.jl missing")
	end)
	table.insert(steps, function()
		local ghost = require("blink.cmp.completion.windows.ghost_text")
		assert(ghost.extmark_id, "Missing path preview")
		local mark = vim.api.nvim_buf_get_extmark_by_id(
			0,
			require("blink.cmp.config").appearance.highlight_ns,
			ghost.extmark_id,
			{}
		)
		assert(mark[2] == #initial, "Preview moved outside the filename: " .. vim.inspect(mark))
		vim.api.nvim_input("<CR>")
	end)
	table.insert(steps, function()
		local expected = 'include("' .. (prefix:match(".*/") or "") .. 'simd.jl")'
		assert(vim.api.nvim_get_current_line() == expected, vim.inspect(vim.api.nvim_get_current_line()))
		vim.api.nvim_input("<Esc>")
	end)
end
local index = 0
local function advance()
	index = index + 1
	local ok, err = pcall(function()
		if steps[index] then
			steps[index]()
			vim.defer_fn(advance, 200)
		else
			cleanup()
			print("JULIA_INCLUDE_COMPLETION_OK: 4 native input, preview and Enter cases")
			vim.cmd("qa!")
		end
	end)
	if not ok then
		cleanup()
		print("Julia completion failed at step " .. index .. ": " .. tostring(err))
		vim.cmd("cquit 1")
	end
end
vim.defer_fn(advance, 0)
