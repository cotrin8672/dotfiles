local parsers = {
	"bash",
	"css",
	"html",
	"java",
	"javascript",
	"json",
	"kotlin",
	"lua",
	"markdown",
	"markdown_inline",
	"nix",
	"rust",
	"toml",
	"tsx",
	"typescript",
	"zsh",
	"latex",
	"matlab",
}

return {
	"nvim-treesitter/nvim-treesitter",
	event = { "BufReadPost", "BufNewFile" },
	priority = 1000,
	build = ":TSUpdate",
	config = function()
		local install = require("nvim-treesitter.install")
		local treesitter = require("nvim-treesitter")

		install.compilers = {
			"zig",
			"clang",
			"gcc",
			"cc",
		}

		treesitter.setup({
			ensure_installed = parsers,
			auto_install = false,
			sync_install = false,
		})

		local group = vim.api.nvim_create_augroup("NvimTreesitter", { clear = true })

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			callback = function(event)
				pcall(vim.treesitter.start, event.buf)
			end,
		})

		vim.schedule(function()
			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype ~= "" then
					pcall(vim.treesitter.start, buf)
				end
			end
		end)
	end,
}
