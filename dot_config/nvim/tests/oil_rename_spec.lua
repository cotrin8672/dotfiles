describe("Oil native LSP file operations", function()
	it("updates references before a batch rename and sends one completion notification", function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/oil.nvim")
		local spec = require("plugins.oil")
		spec.config(nil, spec.opts)
		assert.is_true(require("oil.config").lsp_file_methods.enabled)
		assert.is_false(require("oil.config").lsp_file_methods.autosave_changes)
		local root = vim.fs.normalize(vim.fn.tempname())
		vim.fn.mkdir(root, "p")
		local importer = root .. "/main.rs"
		vim.fn.writefile({ "mod first;" }, importer)
		vim.cmd.edit(vim.fn.fnameescape(importer))
		local buf = vim.api.nvim_get_current_buf()
		local from = { root .. "/first.rs", root .. "/日本 語.rs" }
		local to = { root .. "/second.rs", root .. "/new.rs" }
		for _, path in ipairs(from) do vim.fn.writefile({ "" }, path) end
		local requests, notifications = {}, {}
		local filters = { { scheme = "file", pattern = { glob = "**/*.rs", matches = "file" } } }
		local client = {
			workspace_folders = { { uri = vim.uri_from_fname(root), name = root } },
			server_capabilities = { workspace = { fileOperations = {
				willRename = { filters = filters }, didRename = { filters = filters },
			} } },
			offset_encoding = "utf-16",
			request_sync = function(_, method, params)
				requests[#requests + 1] = { method = method, params = params }
				assert.is_truthy(vim.uv.fs_stat(from[1]))
				return { result = { changes = { [vim.uri_from_fname(importer)] = {
					{ range = { start = { line = 0, character = 4 }, ["end"] = { line = 0, character = 9 } }, newText = "second" },
				} } } }
			end,
			notify = function(_, method, params)
				notifications[#notifications + 1] = { method = method, params = params }
			end,
		}
		local get_clients, previous_snacks = vim.lsp.get_clients, _G.Snacks
		vim.lsp.get_clients = function(opts)
			if opts.method:find("RenameFiles", 1, true) then return { client } end
			return {}
		end
		_G.Snacks = { rename = { on_rename_file = function() error("duplicate rename hook") end } }
		local ok, err = pcall(function()
			local fs = require("oil.fs")
			local function url(path)
				return "oil://" .. fs.os_to_posix_path(vim.uri_to_fname(vim.uri_from_fname(path)))
			end
			local actions = {}
			for i = 1, 2 do actions[i] = { type = "move", src_url = url(from[i]), dest_url = url(to[i]) } end
			local done = require("oil.lsp.helpers").will_perform_file_operations(actions)
			assert.are.equal(1, #requests)
			assert.are.equal(2, #requests[1].params.files)
			for _, file in ipairs(requests[1].params.files) do
				assert.is_true(vim.startswith(file.oldUri, "file:///"))
				assert.is_falsy(file.oldUri:find("oil:", 1, true))
			end
			assert.same({ "mod second;" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
			for i = 1, 2 do assert(vim.uv.fs_rename(from[i], to[i])) end
			done()
			vim.api.nvim_exec_autocmds("User", { pattern = "OilActionsPost", data = { actions = actions } })
			assert.are.equal(1, #notifications)
			assert.are.equal(2, #notifications[1].params.files)
			assert.is_true(vim.bo[buf].modified)
			assert.same({ "mod first;" }, vim.fn.readfile(importer))
		end)
		vim.lsp.get_clients, _G.Snacks = get_clients, previous_snacks
		vim.api.nvim_buf_delete(buf, { force = true })
		vim.fn.delete(root, "rf")
		assert(ok, err)
	end)
end)
