local function toggle_repl()
	local replise = require("replise")
	local bufnr = replise.get_repl_buffer() or (replise.start() and replise.get_repl_buffer())
	if not bufnr then
		return
	end
	local visible = vim.fn.bufwinid(bufnr)
	if visible ~= -1 then
		vim.api.nvim_win_close(visible, false)
		return
	end

	local width = math.max(1, math.floor(vim.o.columns * 0.88))
	local height = math.max(1, math.floor((vim.o.lines - 2) * 0.65))
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		title = " Julia REPL ",
		title_pos = "center",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height - 2) / 2),
		col = math.floor((vim.o.columns - width - 2) / 2),
	})
	vim.wo[win].winblend = require("shared.float").blend
	vim.keymap.set("n", "<Esc>", "<Cmd>close<CR>", { buffer = bufnr, desc = "Close Julia REPL" })
	vim.keymap.set("n", "<leader>it", "<Cmd>close<CR>", { buffer = bufnr, desc = "Close Julia REPL" })
	vim.keymap.set("t", "<Esc>", [[<C-\><C-n><Cmd>close<CR>]], { buffer = bufnr, desc = "Close Julia REPL" })
	vim.cmd.startinsert()
end

return {
	"cotrin8672/replise.nvim",
	ft = "julia",
	dependencies = { "Vigemus/iron.nvim" },
	keys = {
		{ "<leader>ee", function() require("replise").run_buffer({ save = true }) end, ft = "julia", desc = "Run current file" },
		{ "<leader>ei", function() require("replise").interrupt() end, ft = "julia", desc = "Interrupt execution" },
		{ "<leader>er", function() require("replise").restart() end, ft = "julia", desc = "Restart execution session" },
		{ "<leader>is", function() require("replise").send_line() end, ft = "julia", desc = "Send line to REPL" },
		{ "<leader>is", function() require("replise").send_selection() end, mode = "x", ft = "julia", desc = "Send selection to REPL" },
		{ "<leader>it", toggle_repl, ft = "julia", desc = "Toggle REPL" },
		{ "<CR>", function()
			if not require("replise.inline").focus_here() then
				vim.api.nvim_feedkeys(vim.keycode("<CR>"), "n", false)
			end
		end, ft = "julia", desc = "Enter inline output below cursor" },
		{ "<BS>", function()
			if not require("replise.inline").clear_here() then
				vim.api.nvim_feedkeys(vim.keycode("<BS>"), "n", false)
			end
		end, ft = "julia", desc = "Close inline output below cursor" },
		{ "<leader>ic", function() require("replise.inline").clear_all(0) end, ft = { "julia", "replise_inline" }, desc = "Clear all inline output in buffer" },
		{ "<Esc>", function() require("replise.inline").leave() end, ft = "replise_inline", desc = "Return to code" },
		{ "<BS>", function() require("replise.inline").clear() end, ft = "replise_inline", desc = "Close inline output" },
	},
	opts = function()
		-- Use the real executable on Windows so Ctrl-C does not terminate the mise shim.
		local julia = vim.fn.has("win32") == 1
			and vim.fs.joinpath(vim.env.LOCALAPPDATA, "mise", "installs", "julia", "latest", "bin", "julia.exe")
			or "julia"
		return {
			backends = {
				julia = require("replise.backends.julia").new({
					cmd = { julia },
					instantiate = "on_change",
					revise = true,
					prescript = "using Pkg", -- Add startup code here; runs once per REPL.
				}),
			},
			autostart = { "julia" },
			inline = { enabled = true, style = "rails", max_height = 12, width = "full", max_lines = 1000, col_offset = 4 },
			commands = true,
		}
	end,
}
