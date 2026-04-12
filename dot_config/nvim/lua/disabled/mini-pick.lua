return function()
	local pick = require("mini.pick")
	local extra = require("mini.extra")
	local float = require("shared.float")
	local minipick_case_state = nil

	local function center_picker_window()
		local height = math.floor(vim.o.lines * 0.6)
		local width = math.floor(vim.o.columns * 0.6)

		return {
			anchor = "NW",
			height = height,
			width = width,
			row = math.floor((vim.o.lines - height) / 2),
			col = math.floor((vim.o.columns - width) / 2),
		}
	end

	local function pick_quickfix()
		local qf = vim.fn.getqflist({ id = 0, items = 1, title = 0 })
		local items = qf.items or {}
		if vim.tbl_isempty(items) then
			vim.notify("Quickfix list is empty", vim.log.levels.INFO)
			return
		end

		local entries = vim.tbl_map(function(item)
			local filename = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or item.filename or ""
			filename = filename ~= "" and vim.fn.fnamemodify(filename, ":.") or "[No Name]"
			local text = (item.text or ""):gsub("^%s+", "")
			return {
				bufnr = item.bufnr,
				col = item.col,
				filename = filename,
				lnum = item.lnum,
				text = text,
			}
		end, items)

		pick.start({
			source = {
				name = qf.title ~= "" and ("Quickfix: " .. qf.title) or "Quickfix",
				items = entries,
				choose = function(item)
					local target = item.bufnr > 0 and vim.api.nvim_buf_get_name(item.bufnr) or item.filename
					if target == nil or target == "" then
						return
					end

					vim.cmd("edit " .. vim.fn.fnameescape(target))
					vim.api.nvim_win_set_cursor(0, { item.lnum, math.max((item.col or 1) - 1, 0) })
				end,
			},
			format = function(item)
				return string.format("%s:%d:%d %s", item.filename, item.lnum or 1, item.col or 1, item.text)
			end,
		})
	end

	local function get_octo_repo()
		require("lazy").load({ plugins = { "octo.nvim" } })
		return require("octo.utils").get_remote_name()
	end

	local function octo_list(endpoint, opts)
		opts = opts or {}
		require("lazy").load({ plugins = { "octo.nvim" } })

		local gh = require("octo.gh")
		local repo = get_octo_repo()
		if repo == nil or repo == "" then
			vim.notify("No GitHub remote repository found", vim.log.levels.WARN)
			return nil
		end

		local owner, name = require("octo.utils").split_repo(repo)
		local endpoint_with_query = string.format(
			"repos/%s/%s/%s?per_page=%d&state=%s",
			owner,
			name,
			endpoint,
			opts.per_page or 100,
			opts.state or "open"
		)
		local output, stderr = gh.api.get({
			endpoint_with_query,
			opts = {
				mode = "sync",
			},
		})

		if stderr and stderr ~= "" then
			vim.notify(stderr, vim.log.levels.ERROR)
			return nil
		end

		if output == nil or output == "" then
			return nil
		end

		local ok, items = pcall(vim.json.decode, output)
		if not ok then
			vim.notify("Failed to decode Octo response", vim.log.levels.ERROR)
			return nil
		end

		return items
	end

	local function open_octo_item(kind, number)
		vim.cmd(string.format("Octo %s edit %d", kind, number))
	end

	local function pick_octo_pull_requests()
		local items = octo_list("pulls")
		if items == nil or vim.tbl_isempty(items) then
			vim.notify("No open pull requests", vim.log.levels.INFO)
			return
		end

		local entries = vim.tbl_map(function(item)
			return {
				number = item.number,
				title = item.title,
				author = item.user and item.user.login or "",
				draft = item.draft == true,
				state = item.state,
			}
		end, items)

		pick.start({
			source = {
				name = "GitHub Pull Requests",
				items = entries,
				choose = function(item)
					open_octo_item("pr", item.number)
				end,
			},
			format = function(item)
				local prefix = item.draft and "[DRAFT]" or "[PR]"
				local author = item.author ~= "" and (" @" .. item.author) or ""
				return string.format("%s #%d %s%s", prefix, item.number, item.title, author)
			end,
		})
	end

	local function pick_octo_issues()
		local items = octo_list("issues")
		if items == nil then
			return
		end

		local entries = {}
		for _, item in ipairs(items) do
			if item.pull_request == nil then
				entries[#entries + 1] = {
					number = item.number,
					title = item.title,
					author = item.user and item.user.login or "",
					state = item.state,
				}
			end
		end

		if vim.tbl_isempty(entries) then
			vim.notify("No open issues", vim.log.levels.INFO)
			return
		end

		pick.start({
			source = {
				name = "GitHub Issues",
				items = entries,
				choose = function(item)
					open_octo_item("issue", item.number)
				end,
			},
			format = function(item)
				local author = item.author ~= "" and (" @" .. item.author) or ""
				return string.format("[ISSUE] #%d %s%s", item.number, item.title, author)
			end,
		})
	end

	pick.setup({
		window = {
			config = center_picker_window,
		},
	})

	vim.api.nvim_create_autocmd("ColorScheme", {
		pattern = "*",
		callback = function()
			local mini_pick_bg =
				string.format("#%06x", vim.api.nvim_get_hl(0, { name = "NormalFloat", link = false }).bg)
			vim.api.nvim_set_hl(0, "MiniPickNormal", { bg = mini_pick_bg })
			vim.api.nvim_set_hl(0, "MiniPickBorder", { bg = mini_pick_bg })
			vim.api.nvim_set_hl(0, "MiniPickPrompt", { bg = mini_pick_bg })
			vim.api.nvim_set_hl(0, "MiniPickPreviewLine", { bg = "none" })
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "MiniPickStart",
		callback = function()
			local ok, picker = pcall(pick.get_picker_state)
			if not ok or not picker or not picker.windows or not picker.windows.main then
				return
			end

			if minipick_case_state == nil then
				minipick_case_state = {
					ignorecase = vim.o.ignorecase,
					smartcase = vim.o.smartcase,
				}
			end

			vim.o.ignorecase = true
			vim.o.smartcase = false
			pcall(vim.api.nvim_set_option_value, "winblend", float.blend, { win = picker.windows.main })
		end,
	})

	vim.api.nvim_create_autocmd("User", {
		pattern = "MiniPickStop",
		callback = function()
			if minipick_case_state == nil then
				return
			end

			vim.o.ignorecase = minipick_case_state.ignorecase
			vim.o.smartcase = minipick_case_state.smartcase
			minipick_case_state = nil
		end,
	})

	vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name })

	vim.keymap.set("n", "<leader>pf", function()
		extra.pickers.git_files()
	end, { noremap = true, silent = true, desc = "Pick git files" })

	vim.keymap.set("n", "<leader>pg", function()
		pick.builtin.grep_live()
	end, { noremap = true, silent = true, desc = "Live grep" })

	vim.keymap.set("n", "<leader>pb", function()
		extra.pickers.git_branches()
	end, { noremap = true, silent = true, desc = "Pick git branches" })

	vim.keymap.set("n", "<leader>pd", function()
		extra.pickers.diagnostic({ scope = "all" })
	end, { noremap = true, silent = true, desc = "Pick diagnostics" })

	vim.keymap.set("n", "<leader>ps", function()
		extra.pickers.lsp({ scope = "document_symbol" })
	end, { noremap = true, silent = true, desc = "Pick document symbols" })

	vim.keymap.set("n", "<leader>pS", function()
		extra.pickers.lsp({ scope = "workspace_symbol" })
	end, { noremap = true, silent = true, desc = "Pick workspace symbols" })

	vim.keymap.set("n", "<leader>pq", pick_quickfix, {
		noremap = true,
		silent = true,
		desc = "Pick quickfix items",
	})

	vim.keymap.set("n", "<leader>pp", pick_octo_pull_requests, {
		noremap = true,
		silent = true,
		desc = "Pick GitHub pull requests",
	})

	vim.keymap.set("n", "<leader>pi", pick_octo_issues, {
		noremap = true,
		silent = true,
		desc = "Pick GitHub issues",
	})
end
