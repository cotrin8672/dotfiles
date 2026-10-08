return {
	"cotrin8672/kross.nvim",
	lazy = true,
	build = "gradle jar --no-daemon",
	cmd = { "KrossBuild", "KrossWatchStart", "KrossWatchStop" },
	-- Build explicitly until kross retains saves that arrive during a build.
	opts = { plugin_auto_build = false, watch = false },
	config = function(_, opts)
		local kross = require("kross")
		kross.setup(opts)
		-- lsp.lua owns navigation; kross's deferred duplicates outlive preview buffers.
		vim.api.nvim_clear_autocmds({ group = "kross", event = "LspAttach" })
		vim.api.nvim_create_autocmd("LspAttach", {
			group = "kross",
			callback = function(args)
				kross.attach(vim.lsp.get_client_by_id(args.data.client_id))
			end,
		})
	end,
}
