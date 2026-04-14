local vault = vim.fs.normalize(vim.fn.expand("~/vault"))

return {
	"obsidian-nvim/obsidian.nvim",
	event = {
		event = {
			"BufReadPre",
			"BufNewFile",
		},
		pattern = {
			vault .. "/*.md",
			vault .. "/**/*.md",
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {
		legacy_commands = false,

		workspace = {
			{
				name = "main",
				path = vault,
			},
		},

		completion = {
			blink = true,
			nvim_cmp = false,
			min_chars = 1,
		},

		picker = {
			name = "snacks.pick",
		},

		daily_notes = {
			enabled = false,
		},

		attachments = {
			img_folder = "assets/images",
		},

		callbacks = {
			enter_note = function(note)
				local bufnr = note.bufnr or vim.api.nvim_get_current_buf()

				vim.keymap.set(
					"n",
					"gd",
					"<cmd>Obsidian follow_link<CR>",
					{ buffer = bufnr, desc = "Obsidian: follow link" }
				)

				vim.keymap.set(
					"n",
					"grr",
					"<cmd>Obsidian backlinks<CR>",
					{ buffer = bufnr, desc = "Obsidian: backlinks" }
				)

				vim.keymap.set(
					"n",
					"grn",
					"<cmd>Obsidian rename<CR>",
					{ buffer = bufnr, desc = "Obsidian: rename note" }
				)

				vim.keymap.set("n", "K", "<cmd>Obsidian links<CR>", { buffer = bufnr, desc = "Obsidian: show links" })

				vim.keymap.set("n", "<leader>ot", "<cmd>Obsidian toc<CR>", { buffer = bufnr, desc = "Obsidian: TOC" })

				vim.keymap.set(
					"n",
					"<leader>oi",
					"<cmd>Obsidian paste_img<CR>",
					{ buffer = bufnr, desc = "Obsidian: paste image" }
				)
			end,
		},
	},
}
