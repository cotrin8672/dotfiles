return {
	"nvim-mini/mini.sessions",
	event = "VimEnter",

	opts = {
		autoread = false,
		autowrite = true,
		file = "",
		verbose = {
			read = false,
			write = false,
			delete = true,
		},
	},

	config = function(_, opts)
		local sessions = require("mini.sessions")
		local managed_session_name = nil

		local function git_root(path)
			local dot_git = vim.fs.find(".git", {
				path = path or vim.fn.getcwd(),
				upward = true,
				limit = 1,
			})[1]

			return dot_git and vim.fs.dirname(dot_git) or nil
		end

		local function session_name(root)
			local normalized = vim.fs.normalize(root)
			return "git-" .. normalized:gsub("[:/\\]+", "%%")
		end

		sessions.setup(opts)

		local group = vim.api.nvim_create_augroup("MiniSessionsRepoAutoload", { clear = true })

		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = group,
			callback = function()
				if managed_session_name == nil then
					if vim.g.mini_starter_requested ~= true then
						return
					end

					local root = git_root()
					if not root then
						return
					end

					managed_session_name = session_name(root)
				end

				sessions.write(managed_session_name, { force = true, verbose = false })
			end,
		})
	end,
}
