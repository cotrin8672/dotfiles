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

		local function is_diffview_session_block(block)
			for _, line in ipairs(block) do
				if
					line:find("diffview://", 1, true)
					or line:find("DiffviewFiles", 1, true)
					or line:find("DiffviewFilePanel", 1, true)
					or line:find("DiffviewFileHistory", 1, true)
				then
					return true
				end
			end

			return false
		end

		local function remove_last_tabnew(lines)
			for i = #lines, 1, -1 do
				if lines[i]:match("^tabnew") then
					table.remove(lines, i)
					return
				end
			end
		end

		local function prune_diffview_tabs_from_session(data)
			local lines = vim.fn.readfile(data.path)
			local tabrewind_idx

			for i, line in ipairs(lines) do
				if line == "tabrewind" then
					tabrewind_idx = i
					break
				end
			end
			if not tabrewind_idx then
				return
			end

			local suffix_idx = #lines + 1
			for i = tabrewind_idx + 1, #lines do
				if lines[i]:match("^tabnext %d+$") then
					suffix_idx = i
					break
				end
			end

			local blocks = {}
			local block = {}
			for i = tabrewind_idx + 1, suffix_idx - 1 do
				if lines[i] == "tabnext" then
					table.insert(blocks, block)
					block = {}
				else
					table.insert(block, lines[i])
				end
			end
			table.insert(blocks, block)

			local kept = {}
			local removed = 0
			for _, current_block in ipairs(blocks) do
				if is_diffview_session_block(current_block) then
					removed = removed + 1
				else
					table.insert(kept, current_block)
				end
			end
			if removed == 0 or #kept == 0 then
				return
			end

			local output = vim.list_slice(lines, 1, tabrewind_idx)
			for _ = 1, removed do
				remove_last_tabnew(output)
			end

			for i, kept_block in ipairs(kept) do
				if i > 1 then
					table.insert(output, "tabnext")
				end
				vim.list_extend(output, kept_block)
			end

			local suffix = vim.list_slice(lines, suffix_idx)
			if suffix[1] and suffix[1]:match("^tabnext %d+$") then
				suffix[1] = "tabnext 1"
			end
			vim.list_extend(output, suffix)

			vim.fn.writefile(output, data.path)
			data.modify_time = vim.fn.getftime(data.path)
		end

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

		opts.hooks = vim.tbl_deep_extend("force", opts.hooks or {}, {
			post = {
				write = prune_diffview_tabs_from_session,
			},
		})

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
