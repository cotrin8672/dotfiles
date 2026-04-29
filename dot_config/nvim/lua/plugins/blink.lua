local float = require("shared.float")

return {
	"Saghen/blink.cmp",
	dependencies = {
		{
			"Saghen/blink.lib",
			lazy = true,
		},
	},
	build = function(plugin)
		if vim.uv.os_uname().sysname ~= "Windows_NT" then
			require("blink.cmp").build():wait(60000)
			return
		end

		local native = require("blink.lib.native")
		local repo_root = plugin.dir
		local current_file_path = repo_root .. "/lua/blink/cmp/init.lua"
		local git_commit = native.git_commit(current_file_path)
		local platform = native.platform()
		local result = vim.system({ "cargo", "build", "--release" }, { cwd = repo_root, text = true }):wait()

		if result.code ~= 0 then
			error(result.stderr ~= "" and result.stderr or ("cargo build failed with exit code " .. result.code))
		end

		native.mv(
			repo_root .. "/target/release/blink_cmp_fuzzy" .. platform.lib_extension,
			native.library_path("blink_cmp_fuzzy", git_commit)
		)

		if not native.load("blink_cmp_fuzzy", git_commit) then
			error("Failed to load built blink.cmp native library")
		end
	end,
	event = "InsertEnter",
	opts = {
		keymap = {
			preset = "enter",
		},
		appearance = {
			nerd_font_variant = "mono",
		},
		completion = {
			list = {
				selection = {
					preselect = true,
					auto_insert = false,
				},
			},
			accept = {
				auto_brackets = {
					enabled = true,
				},
			},
			ghost_text = {
				enabled = true,
				show_with_menu = true,
			},
			menu = {
				winblend = float.blend,
			},
			documentation = {
				auto_show = true,
				window = {
					winblend = float.blend,
				},
			},
		},
		sources = {
			default = {
				"lazydev",
				"copilot",
				"buffer",
				"path",
				"lsp",
			},
			providers = {
				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					score_offset = 100,
				},
				copilot = {
					name = "copilot",
					module = "blink-cmp-copilot",
					score_offset = 100,
					async = true,
				},
			},
		},
	},
}
