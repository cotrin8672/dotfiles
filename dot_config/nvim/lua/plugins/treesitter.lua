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
	"nu",
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
		local treesitter = require("nvim-treesitter")

		treesitter.setup({
			install_dir = vim.fn.stdpath("data") .. "/site",
		})

		local group = vim.api.nvim_create_augroup("NvimTreesitter", { clear = true })

		vim.api.nvim_create_autocmd("FileType", {
			group = group,
			callback = function(event)
				pcall(vim.treesitter.start, event.buf)
			end,
		})

		vim.schedule(function()
			treesitter.install(parsers)

			for _, buf in ipairs(vim.api.nvim_list_bufs()) do
				if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype ~= "" then
					pcall(vim.treesitter.start, buf)
				end
			end
		end)
	end,
}
