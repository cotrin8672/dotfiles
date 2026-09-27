describe("Repository session writes", function()
	local sessions, root, cwd, name, writes, original_write, old_session
	before_each(function()
		vim.opt.rtp:append(vim.fn.stdpath("data") .. "/lazy/mini.sessions")
		sessions = require("mini.sessions")
		cwd, old_session = vim.fn.getcwd(), vim.v.this_session
		root = vim.fn.tempname()
		vim.fn.mkdir(root .. "/repo/.git", "p")
		vim.cmd.cd(vim.fn.fnameescape(root .. "/repo"))
		name = "git-" .. vim.fs.normalize(vim.fn.getcwd()):gsub("[:/\\]+", "%%")
		local spec = require("plugins.mini-sessions")
		local opts = vim.deepcopy(spec.opts)
		opts.directory = root .. "/sessions"
		spec.config(nil, opts)
		vim.v.this_session = ""
		writes = {}
		original_write = sessions.write
		sessions.write = function(session_name, write_opts)
			local result = original_write(session_name, write_opts)
			writes[#writes + 1] = vim.fs.normalize(vim.v.this_session)
			return result
		end
	end)
	after_each(function()
		sessions.write = original_write
		vim.api.nvim_del_augroup_by_name("MiniSessionsRepoAutowrite")
		vim.api.nvim_del_augroup_by_name("MiniSessions")
		vim.v.this_session = old_session
		vim.cmd.cd(vim.fn.fnameescape(cwd))
		vim.fn.delete(root, "rf")
	end)
	it("writes a loaded repository session only once, including changes since loading", function()
		sessions.write(name, { force = true })
		writes = {}
		vim.api.nvim_exec_autocmds("VimLeavePre", {})
		assert.same({ vim.fs.normalize(root .. "/sessions/" .. name) }, writes)
	end)
	it("still writes both a separately named current session and the repository session", function()
		sessions.write("manual", { force = true })
		writes = {}
		vim.api.nvim_exec_autocmds("VimLeavePre", {})
		assert.same({
			vim.fs.normalize(root .. "/sessions/manual"),
			vim.fs.normalize(root .. "/sessions/" .. name),
		}, writes)
	end)
	it("creates the repository session when no session is active", function()
		vim.api.nvim_exec_autocmds("VimLeavePre", {})
		assert.same({ vim.fs.normalize(root .. "/sessions/" .. name) }, writes)
	end)
	it("preserves ordinary session text and removes only the Diffview tab", function()
		local path = root .. "/fixture"
		local plain = { "tabnew", "tabrewind", "edit ordinary.lua", "tabnext", "edit other.lua", "tabnext 2" }
		vim.fn.writefile(plain, path)
		sessions.config.hooks.post.write({ path = path })
		assert.same(plain, vim.fn.readfile(path))
		local diff = { "tabnew", "tabrewind", "edit ordinary.lua", "tabnext", "edit diffview://view", "tabnext 2" }
		vim.fn.writefile(diff, path)
		sessions.config.hooks.post.write({ path = path })
		assert.same({ "tabrewind", "edit ordinary.lua", "tabnext 1" }, vim.fn.readfile(path))
	end)
end)
