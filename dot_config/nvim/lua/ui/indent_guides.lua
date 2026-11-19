-- Ordinary guides only; mini.indentscope owns the active scope.
local a, fn = vim.api, vim.fn
local ns = a.nvim_create_namespace("cached_indent_guides")
local buffers, windows = {}, {}
local M = {}

local function signature(line)
	local prefix = line:match("^[ \t]*")
	return #prefix ~= #line and prefix or false
end

local function attach(buf)
	local cache = { prefixes = {}, widths = {} }
	buffers[buf] = cache
	local function reset()
		cache.prefixes, cache.widths = {}, {}
		cache.count = 0
	end
	reset()
	a.nvim_buf_attach(buf, false, {
		on_lines = function(_, _, _, first, old_end, new_end)
			if old_end == first + 1 and new_end == old_end and cache.prefixes[first] ~= nil then
				local line = a.nvim_buf_get_lines(buf, first, new_end, false)[1]
				if line and signature(line) == cache.prefixes[first] then return end
			end
			-- Blank runs depend on their nonblank neighbours; never retain stale widths.
			reset()
			if not cache.pending then
				cache.pending = true
				vim.schedule(function()
					cache.pending = nil
					if buffers[buf] == cache then a.nvim__redraw({ buf = buf, valid = false }) end
				end)
			end
		end,
		on_reload = reset,
		on_detach = function() buffers[buf] = nil end,
	})
	return cache
end

local function width(c, buf, row, sw)
	local w = c.widths[row]
	if w ~= nil then return w end
	local line = a.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line then return 0 end
	local prefix = signature(line)
	if prefix and not prefix:find("\t", 1, true) then
		w = #prefix
	else
		w = a.nvim_buf_call(buf, function()
			if prefix then return fn.indent(row + 1) end
			local p, n = fn.prevnonblank(row + 1), fn.nextnonblank(row + 1)
			local l, r = p > 0 and fn.indent(p) or 0, n > 0 and fn.indent(n) or 0
			local minimum = math.min(l, r)
			return minimum > 0 and l ~= r and minimum + sw or minimum
		end)
	end
	c.prefixes[row], c.widths[row] = prefix, w
	c.count = c.count + 1
	return w
end

function M.setup()
	a.nvim_set_decoration_provider(ns, {
		on_win = function(_, win, buf)
			if vim.bo[buf].buftype ~= "" or vim.b[buf].snacks_indent == false or vim.g.snacks_indent == false then return false end
			local c = buffers[buf] or attach(buf)
			local sw, ts, vts = vim.bo[buf].shiftwidth, vim.bo[buf].tabstop, vim.bo[buf].vartabstop
			if sw == 0 then sw = ts end
			if c.sw ~= sw or c.ts ~= ts or c.vts ~= vts or c.count > 4096 then
				c.prefixes, c.widths, c.count = {}, {}, 0
				c.sw, c.ts, c.vts = sw, ts, vts
			end
			local left = a.nvim_win_call(win, fn.winsaveview).leftcol
			local wrap = vim.wo[win].wrap and vim.wo[win].breakindent
			local s = windows[win]
			if not s or s.left ~= left or s.sw ~= sw or s.wrap ~= wrap then
				s = { left = left, sw = sw, wrap = wrap, marks = {} }
				windows[win] = s
			end
			s.cache = c
		end,
		on_line = function(_, win, buf, row)
			local s = windows[win]
			local w = width(s.cache, buf, row, s.sw)
			for col = math.ceil(s.left / s.sw) * s.sw, w - s.sw, s.sw do
				local opts = s.marks[col]
				if not opts then
					opts = { virt_text = { { "│", "NonText" } }, virt_text_win_col = col - s.left,
						hl_mode = "combine", priority = 1, ephemeral = true, virt_text_repeat_linebreak = s.wrap }
					s.marks[col] = opts
				end
				a.nvim_buf_set_extmark(buf, ns, row, 0, opts)
			end
		end,
	})
	a.nvim_create_autocmd("WinClosed", { callback = function(ev) windows[tonumber(ev.match)] = nil end })
end

return M
