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

		local function should_manage_session()
			return vim.fn.argc() == 0
		end

		sessions.setup(opts)

		local group = vim.api.nvim_create_augroup("MiniSessionsRepoAutowrite", { clear = true })

		vim.api.nvim_create_autocmd("VimLeavePre", {
			group = group,
			callback = function()
				if managed_session_name == nil then
					if not should_manage_session() then
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
